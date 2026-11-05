BeforeAll {
    $repositoryRoot = Split-Path (Split-Path $PSScriptRoot -Parent) -Parent
    Import-Module (Join-Path $repositoryRoot 'src/ERAZER.RemoteControl/ERAZER.RemoteControl.psd1') -Force
    $sqxScripts = Join-Path $repositoryRoot 'scripts/sqx'
    $proxyScript = Join-Path $repositoryRoot 'scripts/network/Sync-ProxyWithNetwork.ps1'
    $restoreScript = Join-Path $repositoryRoot 'scripts/system/Restore-MihomoAutostart.ps1'
    $deployScript = Join-Path $repositoryRoot 'scripts/Deploy-Toolkit.ps1'
}

Describe 'Operational entry-point safety' {
    BeforeEach {
        Mock Get-Process { @() }
        Mock Start-Process { throw 'Unexpected native process launch in tests.' }
        Mock Start-ScheduledTask { throw 'Unexpected task start in tests.' }
        Mock Register-ScheduledTask { throw 'Unexpected task registration in tests.' }
        Mock Invoke-WebRequest { throw 'Unexpected HTTP request in tests.' }
        Mock Get-ToolkitTask { [pscustomobject]@{ QueryState='Missing'; RunState='Unknown'; Enabled=$null } }
    }

    It 'does not register or start a project under WhatIf' {
        & (Join-Path $sqxScripts 'Start-SqxProject.ps1') -Task 1 -WhatIf
        Should -Invoke Start-ScheduledTask -Times 0
        Should -Invoke Register-ScheduledTask -Times 0
        Should -Invoke Invoke-WebRequest -Times 0
        Should -Invoke Start-Process -Times 0
    }

    It 'refuses an existing GUI rather than killing it' {
        Mock Get-Process { [pscustomobject]@{ Id=123; Name='StrategyQuantX' } } -ParameterFilter { $Name -contains 'StrategyQuantX' }
        { & (Join-Path $sqxScripts 'Start-SqxProject.ps1') -WhatIf } | Should -Throw '*GUI is open*'
        Should -Invoke Start-ScheduledTask -Times 0
    }

    It 'does not issue a mutating HTTP command under WhatIf' {
        & (Join-Path $sqxScripts 'Control-Sqx.ps1') -Action start-from-task -Task 2 -WhatIf
        Should -Invoke Invoke-WebRequest -Times 0
    }

    It 'does not stop a project or exit its engine under WhatIf' {
        & (Join-Path $sqxScripts 'Stop-SqxProject.ps1') -StopEngine -WhatIf
        Should -Invoke Invoke-WebRequest -Times 0
    }

    It 'does not register a headless task under WhatIf' {
        & (Join-Path $sqxScripts 'Register-SqxTask.ps1') -WhatIf
        Should -Invoke Register-ScheduledTask -Times 0
    }

    It 'refuses to replace a running task even in a preview' {
        Mock Get-ToolkitTask { [pscustomobject]@{ QueryState='Present'; RunState='Running'; Enabled=$true } }
        { & (Join-Path $sqxScripts 'Register-SqxTask.ps1') -WhatIf } | Should -Throw '*refusing to replace*'
        Should -Invoke Register-ScheduledTask -Times 0
    }

    It 'does not classify an inaccessible task as missing during restoration' {
        Mock Get-ToolkitTask { [pscustomobject]@{ QueryState='AccessDenied'; RunState='Unknown'; Enabled=$null } }
        { & $restoreScript -WhatIf } | Should -Throw '*inaccessible tasks*'
        Should -Invoke Register-ScheduledTask -Times 0
    }

    It 'returns an already healthy task set without invoking a registrar' {
        Mock Get-ToolkitTask { [pscustomobject]@{ QueryState='Present'; RunState='Ready'; Enabled=$true } }
        $result = @(& $restoreScript -WhatIf)
        $result.Count | Should -Be 4
        @($result | Where-Object { $_.QueryState -ne 'Present' }).Count | Should -Be 0
    }

    It 'can simulate the proxy policy without network or registry access' {
        $decision = & $proxyScript -DryRun -SimulateSsid MiFi-1A8F -SimulateGateway 192.168.1.1 -SimulateProxyAvailable $true
        $decision.Action | Should -Be 'Enable'
        $decision.Server | Should -Be '192.168.1.100:7897'
        Should -Invoke Start-Process -Times 0
        Should -Invoke Invoke-WebRequest -Times 0
    }

    It 'does not enable the withdrawn JD proxy even if a stale probe reports success' {
        $decision = & $proxyScript -DryRun -SimulateSsid MiFi706425-5G -SimulateProxyAvailable $true
        $decision.Action | Should -Be 'Disable'
        $decision.Server | Should -Be ''
        Should -Invoke Start-Process -Times 0
        Should -Invoke Invoke-WebRequest -Times 0
    }

    It 'rejects a simulated proxy apply without an explicit dry run' {
        { & $proxyScript -SimulateSsid MiFi706425-5G -SimulateProxyAvailable $true } | Should -Throw '*Simulation requires*'
    }

    It 'does not replace an idle task without explicit Force' {
        Mock Get-ToolkitTask { [pscustomobject]@{ QueryState='Present'; RunState='Ready'; Enabled=$true } }
        { & (Join-Path $sqxScripts 'Register-SqxTask.ps1') -WhatIf } | Should -Throw '*explicit -Force*'
        Should -Invoke Register-ScheduledTask -Times 0
    }

    It 'refuses task registration on a different host before mutation' {
        $override = Join-Path $TestDrive 'foreign-host.psd1'
        Set-Content -LiteralPath $override -Value "@{ Target = @{ HostName = 'NOT-THIS-HOST' } }"
        { & (Join-Path $sqxScripts 'Register-SqxTask.ps1') -LocalConfigPath $override -Confirm:$false } | Should -Throw '*configured target machine*'
        Should -Invoke Register-ScheduledTask -Times 0
    }

    It 'does not report a missing task as started' {
        $override = Join-Path $TestDrive 'current-host-start.psd1'
        Set-Content -LiteralPath $override -Value ("@{ Target = @{ HostName = '" + $env:COMPUTERNAME + "' } }")
        { & (Join-Path $sqxScripts 'Start-SqxProject.ps1') -LocalConfigPath $override -Confirm:$false } | Should -Throw '*Register it explicitly*'
        Should -Invoke Start-ScheduledTask -Times 0
        Should -Invoke Register-ScheduledTask -Times 0
    }

    It 'refuses an incompatible existing task without replacing or starting it' {
        $override = Join-Path $TestDrive 'current-host-mismatch.psd1'
        Set-Content -LiteralPath $override -Value ("@{ Target = @{ HostName = '" + $env:COMPUTERNAME + "' } }")
        Mock Get-ToolkitTask { [pscustomobject]@{ QueryState='Present'; RunState='Ready'; Enabled=$true } }
        Mock Get-ScheduledTask { [pscustomobject]@{ Actions=@([pscustomobject]@{ Execute='wrong.exe'; Arguments=''; WorkingDirectory='' }) } }
        { & (Join-Path $sqxScripts 'Start-SqxProject.ps1') -LocalConfigPath $override -Confirm:$false } | Should -Throw '*does not match*'
        Should -Invoke Start-ScheduledTask -Times 0
        Should -Invoke Register-ScheduledTask -Times 0
    }

    It 'does not treat disabled proxy tasks as a healthy restoration result' {
        $registrar = Join-Path $TestDrive 'registrar.ps1'
        Set-Content -LiteralPath $registrar -Value "throw 'Test registrar must never run.'"
        $override = Join-Path $TestDrive 'disabled-tasks.psd1'
        Set-Content -LiteralPath $override -Value ("@{ Controller = @{ MihomoRegistrar = '" + $registrar + "' } }")
        Mock Get-ToolkitTask { [pscustomobject]@{ QueryState='Present'; RunState='Disabled'; Enabled=$false } }
        @(& $restoreScript -LocalConfigPath $override -WhatIf).Count | Should -Be 0
    }

    It 'refuses remote engine-exit verification before issuing any HTTP command' {
        $override = Join-Path $TestDrive 'remote-api.psd1'
        Set-Content -LiteralPath $override -Value ("@{ Target = @{ HostName = '" + $env:COMPUTERNAME + "' }; Sqx = @{ ApiBase = 'http://192.0.2.10:5050' } }")
        { & (Join-Path $sqxScripts 'Stop-SqxProject.ps1') -StopEngine -LocalConfigPath $override -Confirm:$false } | Should -Throw '*requires local execution*'
        Should -Invoke Invoke-WebRequest -Times 0
    }

    It 'rejects contradictory MT5 options without touching MT5' {
        { & $proxyScript -DryRun -SkipMT5 -UpdateMT5 } | Should -Throw '*either*'
        Should -Invoke Get-Process -Times 0
    }
}

Describe 'Deployment uses synthetic destinations, not machine installation paths' {
    BeforeEach { $destination = Join-Path $TestDrive ([Guid]::NewGuid().ToString('N')) }

    It 'does not create a destination under WhatIf' {
        & $deployScript -DestinationPath $destination -WhatIf
        Test-Path -LiteralPath $destination | Should -BeFalse
    }

    It 'rejects relative destinations' {
        { & $deployScript -DestinationPath 'relative-bundle' -WhatIf } | Should -Throw '*absolute*'
    }

    It 'rejects the checkout itself and its parent before any copies' {
        { & $deployScript -DestinationPath $repositoryRoot -WhatIf } | Should -Throw '*outside the source checkout*'
        { & $deployScript -DestinationPath (Split-Path $repositoryRoot -Parent) -WhatIf } | Should -Throw '*outside the source checkout*'
    }

    It 'rejects replacing an unmanaged folder even with Force' {
        $null = New-Item -ItemType Directory -Path $destination
        $personal = Join-Path $destination 'personal.txt'
        Set-Content -LiteralPath $personal -Value 'keep me'
        { & $deployScript -DestinationPath $destination -Force -Confirm:$false } | Should -Throw '*unmanaged*'
        Get-Content -LiteralPath $personal | Should -Be 'keep me'
    }

    It 'copies only the maintained manifest, with no credentials or archive' {
        $result = & $deployScript -DestinationPath $destination -Confirm:$false
        $manifest = Import-PowerShellDataFile (Join-Path $repositoryRoot 'config/deployment.psd1')
        $result.Files | Should -Be $manifest.Files.Count
        $result.LiveDeployment | Should -BeFalse
        foreach ($relative in $manifest.Files) { Test-Path -LiteralPath (Join-Path $destination $relative) | Should -BeTrue }
        Test-Path -LiteralPath (Join-Path $destination 'credentials.local.txt') | Should -BeFalse
        Test-Path -LiteralPath (Join-Path $destination 'archive') | Should -BeFalse
    }

    It 'backs up an existing managed bundle rather than deleting it' {
        $null = & $deployScript -DestinationPath $destination -Confirm:$false
        $marker = Join-Path $destination 'previous.txt'
        Set-Content -LiteralPath $marker -Value 'retain old bundle'
        $result = & $deployScript -DestinationPath $destination -Force -Confirm:$false
        Test-Path -LiteralPath $result.Backup | Should -BeTrue
        Get-Content -LiteralPath (Join-Path $result.Backup 'previous.txt') | Should -Be 'retain old bundle'
        Test-Path -LiteralPath (Join-Path $destination 'previous.txt') | Should -BeFalse
    }
}

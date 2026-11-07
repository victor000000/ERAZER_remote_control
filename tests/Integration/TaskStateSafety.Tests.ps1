BeforeAll {
    $root = Split-Path (Split-Path $PSScriptRoot -Parent) -Parent
    Import-Module (Join-Path $root 'src/ERAZER.RemoteControl/ERAZER.RemoteControl.psd1') -Force
    $register = Join-Path $root 'scripts/sqx/Register-SqxTask.ps1'
    $start = Join-Path $root 'scripts/sqx/Start-SqxProject.ps1'
}

Describe 'Fail-closed scheduled task changes' {
    BeforeEach {
        $override = Join-Path $TestDrive 'target.psd1'
        Set-Content -LiteralPath $override -Value ("@{ Target = @{ HostName = '" + $env:COMPUTERNAME + "' } }")
        Mock Get-Process { @() }
        Mock Register-ScheduledTask { throw 'Forbidden task registration' }
        Mock Start-ScheduledTask { throw 'Forbidden task start' }
        Mock Export-ScheduledTask { throw 'Forbidden task export' }
        Mock Get-ScheduledTask { throw 'Forbidden task definition query' }
        Mock Invoke-WebRequest { throw 'Forbidden HTTP request' }
    }

    It 'rejects replacement when the task run state is uncertain' -TestCases @(
        @{ State = 'Unknown' }, @{ State = 'Unexpected' }, @{ State = '' }
    ) {
        param($State)
        Mock Get-ToolkitTask { [pscustomobject]@{ QueryState='Present'; RunState=$State; Enabled=$true } }
        { & $register -LocalConfigPath $override -Force -Confirm:$false } | Should -Throw '*not confirmed idle*'
        Should -Invoke Register-ScheduledTask -Times 0
        Should -Invoke Export-ScheduledTask -Times 0
    }

    It 'rejects an unrecognized query result instead of treating it as missing' {
        Mock Get-ToolkitTask { [pscustomobject]@{ QueryState='Unexpected'; RunState='Ready'; Enabled=$true } }
        { & $register -LocalConfigPath $override -Force -Confirm:$false } | Should -Throw '*Cannot inspect*'
        Should -Invoke Register-ScheduledTask -Times 0
    }

    It 'protects the reserved preserving task from replacement and recreation' -TestCases @(
        @{ Query='Present'; State='Ready' }, @{ Query='Missing'; State='Unknown' }
    ) {
        param($Query, $State)
        Mock Get-ToolkitTask { [pscustomobject]@{ QueryState=$Query; RunState=$State; Enabled=$true } }
        { & $register -LocalConfigPath $override -Force -Confirm:$false } | Should -Throw '*preserving task is protected*'
        Should -Invoke Register-ScheduledTask -Times 0
        Should -Invoke Export-ScheduledTask -Times 0
    }

    It 'rejects starting a task that is not confirmed ready' -TestCases @(
        @{ State='Unknown' }, @{ State='Unexpected' }, @{ State='' }
    ) {
        param($State)
        Mock Get-ToolkitTask { [pscustomobject]@{ QueryState='Present'; RunState=$State; Enabled=$true } }
        { & $start -LocalConfigPath $override -Confirm:$false } | Should -Throw '*not confirmed ready*'
        Should -Invoke Start-ScheduledTask -Times 0
        Should -Invoke Get-ScheduledTask -Times 0
        Should -Invoke Invoke-WebRequest -Times 0
    }

    It 'starts a reviewed enabled Ready task with its exact configured action' {
        Set-Content -LiteralPath $override -Value ("@{ Target = @{ HostName = '" + $env:COMPUTERNAME + "' }; Sqx = @{ TaskName = 'SyntheticHeadless' } }")
        $config = Get-ToolkitConfig -LocalPath $override
        $spec = New-SqxTaskAction -EngineScript (Join-Path $root 'scripts/sqx/Start-SqxEngine.ps1') -Project $config.Sqx.Project -Task 1 -LocalConfigPath $override
        Mock Get-ToolkitTask { [pscustomobject]@{ QueryState='Present'; RunState='Ready'; Enabled=$true } }
        Mock Get-ScheduledTask { [pscustomobject]@{ Actions=@([pscustomobject]@{ Execute=$spec.Execute; Arguments=$spec.Arguments; WorkingDirectory=$config.Sqx.InstallDirectory }) } }
        Mock Start-ScheduledTask { }
        Mock Wait-SqxReady { [pscustomobject]@{ Generated=0 } }
        $result = & $start -LocalConfigPath $override -Confirm:$false
        $result.Generated | Should -Be 0
        Should -Invoke Start-ScheduledTask -Times 1 -Exactly -ParameterFilter { $TaskName -eq 'SyntheticHeadless' }
        Should -Invoke Wait-SqxReady -Times 1 -Exactly
        Should -Invoke Register-ScheduledTask -Times 0
        Should -Invoke Invoke-WebRequest -Times 0
    }

    It 'protects case and root-path variants of the reserved task name' -TestCases @(
        @{ Name='sqx-task1-headless' }, @{ Name='\SQX-Task1-Headless' }
    ) {
        param($Name)
        Set-Content -LiteralPath $override -Value ("@{ Target = @{ HostName = '" + $env:COMPUTERNAME + "' }; Sqx = @{ TaskName = '" + $Name + "' } }")
        Mock Get-ToolkitTask { [pscustomobject]@{ QueryState='Present'; RunState='Ready'; Enabled=$true } }
        { & $register -LocalConfigPath $override -Force -Confirm:$false } | Should -Throw '*preserving task is protected*'
        Should -Invoke Register-ScheduledTask -Times 0
        Should -Invoke Export-ScheduledTask -Times 0
    }

}

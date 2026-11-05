# Pester 5.7.1. Registry/native commands fail closed; no successful WinINET write path reaches P/Invoke.
BeforeAll {
    $modulePath = Join-Path $PSScriptRoot '../../src/ERAZER.RemoteControl/ERAZER.RemoteControl.psd1'
    Import-Module $modulePath -Force -ErrorAction Stop
    # A module-local command seam makes the netsh mock portable and prevents falling through to a native executable.
    & (Get-Module ERAZER.RemoteControl) {
        function script:netsh.exe { throw 'Forbidden real netsh invocation' }
    }
    $syntheticProxyMap = @{
        HypoMux = '<gateway>:7897'
        'MiFi-1A8F' = '192.168.1.100:7897'
        'MiFi706425-5G' = '192.168.0.2:7897'
    }
}

AfterAll {
    & (Get-Module ERAZER.RemoteControl) {
        Remove-Item -LiteralPath Function:netsh.exe -ErrorAction SilentlyContinue
        Remove-Variable -Name LASTEXITCODE -Scope Script -ErrorAction SilentlyContinue
    }
}

Describe 'Proxy offline regression contracts' {
    BeforeEach {
        Mock Get-ItemProperty -ModuleName ERAZER.RemoteControl { throw 'Forbidden live registry read' }
        Mock Set-ItemProperty -ModuleName ERAZER.RemoteControl { throw 'Forbidden live registry write' }
        Mock Remove-ItemProperty -ModuleName ERAZER.RemoteControl { throw 'Forbidden live registry delete' }
        Mock Add-Type -ModuleName ERAZER.RemoteControl { throw 'Forbidden P/Invoke type creation' }
        Mock netsh.exe -ModuleName ERAZER.RemoteControl { throw 'Forbidden live netsh' }
        Mock Start-Process -ModuleName ERAZER.RemoteControl { throw 'Forbidden process launch' }
        Mock Invoke-WebRequest -ModuleName ERAZER.RemoteControl { throw 'Forbidden HTTP' }
        Mock Import-PowerShellDataFile -ModuleName ERAZER.RemoteControl { throw 'Forbidden live config read' }
        Mock New-Object -ModuleName ERAZER.RemoteControl { throw 'Forbidden object creation' }
        Mock Test-ProxyEndpoint -ModuleName ERAZER.RemoteControl { throw 'Forbidden network probe' }
    }

    Context 'Pure network-to-proxy decisions' {
        It 'maps known network <Ssid> to <Expected>' -ForEach @(
            @{ Ssid = 'HypoMux'; Gateway = '192.168.137.1'; Expected = '192.168.137.1:7897' }
            @{ Ssid = 'MiFi-1A8F'; Gateway = ''; Expected = '192.168.1.100:7897' }
            @{ Ssid = 'MiFi706425-5G'; Gateway = ''; Expected = '192.168.0.2:7897' }
        ) {
            $result = Get-ProxyDecision -Ssid $Ssid -Gateway $Gateway -ProxyMap $syntheticProxyMap -ProbeSucceeded $true
            $result.Action | Should -Be 'Enable'
            $result.Server | Should -BeExactly $Expected
            $result.Endpoint | Should -BeExactly ($Ssid + '|' + $Expected)
            $result.Failures | Should -Be 0
            $result.UnknownObservations | Should -Be 0
            Should -Invoke Test-ProxyEndpoint -ModuleName ERAZER.RemoteControl -Times 0 -Exactly
            Should -Invoke Get-ItemProperty -ModuleName ERAZER.RemoteControl -Times 0 -Exactly
        }

        It 'uses case-sensitive exact SSID matching for <Ssid>' -ForEach @(
            @{ Ssid = 'hypomux' }, @{ Ssid = 'MIFI-1A8F' }, @{ Ssid = 'mifi706425-5g' },
            @{ Ssid = 'MiFi706425-5G ' }, @{ Ssid = 'OtherNetwork' }
        ) {
            $result = Get-ProxyDecision -Ssid $Ssid -Gateway '192.168.137.1' -ProxyMap $syntheticProxyMap -ProbeSucceeded $true
            $result.Action | Should -Be 'Disable'
            $result.Server | Should -BeExactly ''
            $result.Reason | Should -Be 'Unrecognized network'
        }

        It 'rejects missing or invalid gateway <Label> instead of producing a usable endpoint' -ForEach @(
            @{ Label = 'missing'; Gateway = '' }, @{ Label = 'garbage'; Gateway = 'not-an-ip' },
            @{ Label = 'IPv6'; Gateway = '::1' }, @{ Label = 'host-port'; Gateway = '192.168.137.1:7897' },
            @{ Label = 'out-of-range IPv4'; Gateway = '999.168.137.1' }
        ) {
            $result = Get-ProxyDecision -Ssid HypoMux -Gateway $Gateway -ProxyMap $syntheticProxyMap -ProbeSucceeded $true
            $result.Action | Should -Be 'Disable'
            $result.Server | Should -BeExactly ''
            $result.Reason | Should -Be 'No valid proxy endpoint for network'
        }

        It 'holds when a recognized endpoint has not yet been probed' {
            $result = Get-ProxyDecision -Ssid 'MiFi706425-5G' -ProxyMap $syntheticProxyMap
            $result.Action | Should -Be 'Hold'
            $result.Server | Should -Be '192.168.0.2:7897'
            $result.Reason | Should -Be 'Proxy probe not available'
        }

        It 'counts consecutive failures for the same exact endpoint and disables at the threshold' {
            $first = Get-ProxyDecision -Ssid 'MiFi706425-5G' -ProxyMap $syntheticProxyMap -ProbeSucceeded $false
            $first.Action | Should -Be 'Hold'
            $first.Failures | Should -Be 1
            $second = Get-ProxyDecision -Ssid 'MiFi706425-5G' -ProxyMap $syntheticProxyMap -ProbeSucceeded $false -PreviousEndpoint $first.Endpoint -Failures $first.Failures
            $second.Action | Should -Be 'Hold'
            $second.Failures | Should -Be 2
            $third = Get-ProxyDecision -Ssid 'MiFi706425-5G' -ProxyMap $syntheticProxyMap -ProbeSucceeded $false -PreviousEndpoint $second.Endpoint -Failures $second.Failures
            $third.Action | Should -Be 'Disable'
            $third.Failures | Should -Be 3
            $third.Reason | Should -Be 'Proxy failure threshold reached'
        }

        It 'does not transfer a previous network failure count to a new endpoint' {
            $result = Get-ProxyDecision -Ssid 'MiFi706425-5G' -ProxyMap $syntheticProxyMap -ProbeSucceeded $false -PreviousEndpoint 'MiFi-1A8F|192.168.1.100:7897' -Failures 99
            $result.Action | Should -Be 'Hold'
            $result.Failures | Should -Be 1
            $changedGateway = Get-ProxyDecision -Ssid HypoMux -Gateway '192.168.137.2' -ProxyMap $syntheticProxyMap -ProbeSucceeded $false -PreviousEndpoint 'HypoMux|192.168.137.1:7897' -Failures 99
            $changedGateway.Failures | Should -Be 1
            $changedCase = Get-ProxyDecision -Ssid HypoMux -Gateway '192.168.137.1' -ProxyMap $syntheticProxyMap -ProbeSucceeded $false -PreviousEndpoint 'hypomux|192.168.137.1:7897' -Failures 99
            $changedCase.Failures | Should -Be 1
        }

        It 'resets failures and unknown observations following a successful probe' {
            $result = Get-ProxyDecision -Ssid HypoMux -Gateway '192.168.137.1' -ProxyMap $syntheticProxyMap -ProbeSucceeded $true -PreviousEndpoint 'HypoMux|192.168.137.1:7897' -Failures 99 -UnknownObservations 99
            $result.Action | Should -Be 'Enable'
            $result.Failures | Should -Be 0
            $result.UnknownObservations | Should -Be 0
        }

        It 'honors a custom failure threshold of one' {
            (Get-ProxyDecision -Ssid 'MiFi-1A8F' -ProxyMap $syntheticProxyMap -ProbeSucceeded $false -FailureThreshold 1).Action | Should -Be 'Disable'
        }

        It 'bounds unknown network observation holds and then disables' {
            foreach ($count in 0..3) {
                $result = Get-ProxyDecision -Ssid '' -ProxyMap $syntheticProxyMap -UnknownObservations $count -UnknownThreshold 3 -InterfaceAlias 'Wi-Fi'
                $result.UnknownObservations | Should -Be ([math]::Min(3, $count + 1))
                if ($count -lt 2) { $result.Action | Should -Be 'Hold' }
                else { $result.Action | Should -Be 'Disable' }
                $result.Server | Should -BeExactly ''
            }
        }

        It 'saturates an already prolonged failure counter at its configured threshold <Threshold>' -ForEach @(
            @{ Threshold = 3 }, @{ Threshold = 7 }
        ) {
            $result = Get-ProxyDecision -Ssid 'MiFi706425-5G' -ProxyMap $syntheticProxyMap -ProbeSucceeded $false `
                -PreviousEndpoint 'MiFi706425-5G|192.168.0.2:7897' -Failures 999 -FailureThreshold $Threshold
            $result.Failures | Should -Be $Threshold
            $result.Action | Should -Be 'Disable'
        }

        It 'keeps failure decisions callable for more than 1000 observations and recovers after success' {
            $failures = 0
            $endpoint = 'MiFi706425-5G|192.168.0.2:7897'
            foreach ($observation in 1..1005) {
                $result = Get-ProxyDecision -Ssid 'MiFi706425-5G' -ProxyMap $syntheticProxyMap -ProbeSucceeded $false `
                    -PreviousEndpoint $endpoint -Failures $failures
                $failures = $result.Failures
                if ($failures -gt 3 -or $failures -lt 1) { throw "Unbounded failure count at observation $observation" }
            }
            $result.Failures | Should -Be 3
            $result.Action | Should -Be 'Disable'
            $recovered = Get-ProxyDecision -Ssid 'MiFi706425-5G' -ProxyMap $syntheticProxyMap -ProbeSucceeded $true `
                -PreviousEndpoint $endpoint -Failures $result.Failures
            $recovered.Action | Should -Be 'Enable'
            $recovered.Failures | Should -Be 0
            Should -Invoke Test-ProxyEndpoint -ModuleName ERAZER.RemoteControl -Times 0 -Exactly
        }

        It 'saturates unknown observations at threshold <Threshold>, including input 999 and repeated checks' -ForEach @(
            @{ Threshold = 3 }, @{ Threshold = 7 }
        ) {
            $result = Get-ProxyDecision -Ssid '' -ProxyMap $syntheticProxyMap -UnknownObservations 999 -UnknownThreshold $Threshold -InterfaceAlias 'Wi-Fi'
            $result.UnknownObservations | Should -Be $Threshold
            $result.Action | Should -Be 'Disable'
            foreach ($observation in 1..1005) {
                $result = Get-ProxyDecision -Ssid '' -ProxyMap $syntheticProxyMap -UnknownObservations $result.UnknownObservations -UnknownThreshold $Threshold -InterfaceAlias 'Wi-Fi'
                if ($result.UnknownObservations -ne $Threshold) { throw "Unknown counter escaped its saturation bound at observation $observation" }
            }
            $result.UnknownObservations | Should -Be $Threshold
            $result.Action | Should -Be 'Disable'
            $recovered = Get-ProxyDecision -Ssid 'MiFi706425-5G' -ProxyMap $syntheticProxyMap -UnknownObservations $result.UnknownObservations -ProbeSucceeded $true
            $recovered.UnknownObservations | Should -Be 0
            $recovered.Action | Should -Be 'Enable'
        }

        It 'disables immediately when an unknown SSID is observed on a non-wireless route' {
            $result = Get-ProxyDecision -Ssid '' -ProxyMap $syntheticProxyMap -InterfaceAlias Ethernet
            $result.Action | Should -Be 'Disable'
            $result.Reason | Should -Be 'No Wi-Fi SSID; route is not wireless'
        }

        It 'allows only bounded counters and positive thresholds' {
            { Get-ProxyDecision -Ssid '' -ProxyMap $syntheticProxyMap -Failures -1 } | Should -Throw
            { Get-ProxyDecision -Ssid '' -ProxyMap $syntheticProxyMap -UnknownObservations 1000 } | Should -Throw
            { Get-ProxyDecision -Ssid '' -ProxyMap $syntheticProxyMap -FailureThreshold 0 } | Should -Throw
            { Get-ProxyDecision -Ssid '' -ProxyMap $syntheticProxyMap -UnknownThreshold 100 } | Should -Throw
        }
    }

    Context 'Section-aware literal INI updates' {
        It 'updates only the selected section and preserves CRLF, comments and other sections' {
            $content = "; preamble`r`n[Other]`r`nServer=keep`r`n[Proxy]`r`n; comment`r`nServer=old`r`nEnabled=1`r`n[Later]`r`nServer=also keep`r`n"
            $result = Set-IniSectionValue -Content $content -Section Proxy -Name Server -Value 'new:7897'
            $expected = "; preamble`r`n[Other]`r`nServer=keep`r`n[Proxy]`r`n; comment`r`nServer=new:7897`r`nEnabled=1`r`n[Later]`r`nServer=also keep`r`n"
            $result | Should -BeExactly $expected
            $result | Should -Not -Match '(?<!\r)\n'
        }

        It 'preserves LF-only files and matches section names case-insensitively' {
            Set-IniSectionValue -Content "[pRoXy]`nServer=old`n" -Section PROXY -Name Server -Value 'new' |
                Should -BeExactly "[pRoXy]`nServer=new`n"
        }

        It 'treats regex metacharacters in key names and dollar replacements literally' {
            $value = '$1 ${name} $& $$ X:\[literal]\&a=b'
            $content = "[Proxy]`r`nKey[1].+=old`r`nKey11=keep`r`n"
            Set-IniSectionValue -Content $content -Section Proxy -Name 'Key[1].+' -Value $value |
                Should -BeExactly ("[Proxy]`r`nKey[1].+=" + $value + "`r`nKey11=keep`r`n")
        }

        It 'inserts a missing key inside the target section, not into the next section' {
            Set-IniSectionValue -Content "[Proxy]`nEnabled=1`n[Next]`nServer=keep`n" -Section Proxy -Name Server -Value 'new' |
                Should -BeExactly "[Proxy]`nServer=new`nEnabled=1`n[Next]`nServer=keep`n"
        }

        It 'adds a missing section with a single final newline in the existing newline style' {
            Set-IniSectionValue -Content "[Other]`r`nServer=keep`r`n`r`n" -Section Proxy -Name Server -Value '$1' |
                Should -BeExactly "[Other]`r`nServer=keep`r`n[Proxy]`r`nServer=`$1`r`n"
            Set-IniSectionValue -Content '' -Section Proxy -Name Server -Value '' |
                Should -BeExactly "[Proxy]`nServer=`n"
        }

        It 'updates all duplicate matching keys within the selected section and is idempotent' {
            $content = "[Proxy]`n Server =one`nServer=two`n[Other]`nServer=keep"
            $first = Set-IniSectionValue -Content $content -Section Proxy -Name Server -Value '$&'
            $first | Should -BeExactly "[Proxy]`nServer=`$&`nServer=`$&`n[Other]`nServer=keep"
            Set-IniSectionValue -Content $first -Section Proxy -Name Server -Value '$&' | Should -BeExactly $first
        }

        It 'does not interpret comments or prefix keys as the selected key' {
            $content = "[Proxy]`n;Server=comment`nServerExtra=keep`n[Next]`nServer=keep"
            Set-IniSectionValue -Content $content -Section Proxy -Name Server -Value new |
                Should -BeExactly "[Proxy]`nServer=new`n;Server=comment`nServerExtra=keep`n[Next]`nServer=keep"
        }

        It 'rejects section/key/value injection <Label>' -ForEach @(
            @{ Label = 'section bracket'; Section = '[Proxy]'; Name = 'Server'; Value = 'safe' }
            @{ Label = 'section LF'; Section = "Proxy`nOther"; Name = 'Server'; Value = 'safe' }
            @{ Label = 'key equals'; Section = 'Proxy'; Name = 'Server=x'; Value = 'safe' }
            @{ Label = 'key CR'; Section = 'Proxy'; Name = "Server`rOther"; Value = 'safe' }
            @{ Label = 'value newline'; Section = 'Proxy'; Name = 'Server'; Value = "new`nInjected=1" }
        ) {
            { Set-IniSectionValue -Content '[Proxy]' -Section $Section -Name $Name -Value $Value } | Should -Throw '*Invalid INI*'
        }
    }

    Context 'WinINET reporting is transactional, without calling P/Invoke' {
        BeforeEach {
            $registryKey = 'HKCU:\Software\Microsoft\Windows\CurrentVersion\Internet Settings'
            $oldProxy = [pscustomobject]@{ ProxyEnable = 0; ProxyServer = 'old:7897'; ProxyOverride = 'old bypass' }
            Mock Get-ItemProperty -ModuleName ERAZER.RemoteControl { $oldProxy }
        }

        It 'returns false and does not write or load native types when already enabled correctly' {
            $oldProxy = [pscustomobject]@{ ProxyEnable = 1; ProxyServer = 'new:7897'; ProxyOverride = '<local>;192.168.*;10.*;169.254.*' }
            Set-WinInetProxy -On $true -Server 'new:7897' | Should -BeFalse
            Should -Invoke Set-ItemProperty -ModuleName ERAZER.RemoteControl -Times 0 -Exactly
            Should -Invoke Remove-ItemProperty -ModuleName ERAZER.RemoteControl -Times 0 -Exactly
            Should -Invoke Add-Type -ModuleName ERAZER.RemoteControl -Times 0 -Exactly
        }

        It 'returns false when already disabled even if old server settings remain' {
            Set-WinInetProxy -On $false | Should -BeFalse
            Should -Invoke Set-ItemProperty -ModuleName ERAZER.RemoteControl -Times 0 -Exactly
            Should -Invoke Add-Type -ModuleName ERAZER.RemoteControl -Times 0 -Exactly
        }

        It 'WhatIf never falsely reports applied and never writes, deletes or notifies' {
            Set-WinInetProxy -On $true -Server 'new:7897' -WhatIf | Should -BeFalse
            $oldProxy.ProxyEnable = 1
            Set-WinInetProxy -On $false -WhatIf | Should -BeFalse
            Should -Invoke Set-ItemProperty -ModuleName ERAZER.RemoteControl -Times 0 -Exactly
            Should -Invoke Remove-ItemProperty -ModuleName ERAZER.RemoteControl -Times 0 -Exactly
            Should -Invoke Add-Type -ModuleName ERAZER.RemoteControl -Times 0 -Exactly
        }

        It 'rejects enabling without a server before even reading registry' {
            { Set-WinInetProxy -On $true -Server ' ' } | Should -Throw '*server is required*'
            Should -Invoke Get-ItemProperty -ModuleName ERAZER.RemoteControl -Times 0 -Exactly
            Should -Invoke Set-ItemProperty -ModuleName ERAZER.RemoteControl -Times 0 -Exactly
        }

        It 'propagates registry read failures without any write or false applied result' {
            Mock Get-ItemProperty -ModuleName ERAZER.RemoteControl { throw 'synthetic registry read denied' }
            { Set-WinInetProxy -On $true -Server 'new:7897' } | Should -Throw '*registry read denied*'
            Should -Invoke Set-ItemProperty -ModuleName ERAZER.RemoteControl -Times 0 -Exactly
            Should -Invoke Add-Type -ModuleName ERAZER.RemoteControl -Times 0 -Exactly
        }

        It 'propagates a first write failure before Add-Type or native notifications' {
            Mock Set-ItemProperty -ModuleName ERAZER.RemoteControl { throw 'synthetic first write denied' }
            { Set-WinInetProxy -On $true -Server 'new:7897' } | Should -Throw '*first write denied*'
            Should -Invoke Set-ItemProperty -ModuleName ERAZER.RemoteControl -Times 1 -Exactly -ParameterFilter {
                $LiteralPath -eq $registryKey -and $Name -eq 'ProxyServer' -and $Value -eq 'new:7897' -and $Type -eq 'String' -and $ErrorAction -eq 'Stop'
            }
            Should -Invoke Remove-ItemProperty -ModuleName ERAZER.RemoteControl -Times 0 -Exactly
            Should -Invoke Add-Type -ModuleName ERAZER.RemoteControl -Times 0 -Exactly
        }

        It 'restores an earlier successful value when a subsequent write fails' {
            Mock Set-ItemProperty -ModuleName ERAZER.RemoteControl { throw 'Unexpected registry write' }
            Mock Set-ItemProperty -ModuleName ERAZER.RemoteControl {} -ParameterFilter { $Name -eq 'ProxyServer' -and $Value -eq 'new:7897' }
            Mock Set-ItemProperty -ModuleName ERAZER.RemoteControl { throw 'synthetic second write denied' } -ParameterFilter { $Name -eq 'ProxyOverride' }
            Mock Set-ItemProperty -ModuleName ERAZER.RemoteControl {} -ParameterFilter { $Name -eq 'ProxyServer' -and $Value -eq 'old:7897' }
            { Set-WinInetProxy -On $true -Server 'new:7897' } | Should -Throw '*second write denied*'
            Should -Invoke Set-ItemProperty -ModuleName ERAZER.RemoteControl -Times 1 -Exactly -ParameterFilter { $Name -eq 'ProxyServer' -and $Value -eq 'old:7897' }
            Should -Invoke Set-ItemProperty -ModuleName ERAZER.RemoteControl -Times 0 -Exactly -ParameterFilter { $Name -eq 'ProxyEnable' }
            Should -Invoke Add-Type -ModuleName ERAZER.RemoteControl -Times 0 -Exactly
        }

        It 'deletes newly introduced values on rollback when they did not exist before the failed write' {
            $oldProxy = [pscustomobject]@{ ProxyEnable = 0 }
            Mock Set-ItemProperty -ModuleName ERAZER.RemoteControl { throw 'Unexpected registry write' }
            Mock Set-ItemProperty -ModuleName ERAZER.RemoteControl {} -ParameterFilter { $Name -eq 'ProxyServer' }
            Mock Set-ItemProperty -ModuleName ERAZER.RemoteControl { throw 'synthetic missing-property rollback' } -ParameterFilter { $Name -eq 'ProxyOverride' }
            Mock Remove-ItemProperty -ModuleName ERAZER.RemoteControl {} -ParameterFilter { $Name -eq 'ProxyServer' }
            { Set-WinInetProxy -On $true -Server 'new:7897' } | Should -Throw '*missing-property rollback*'
            Should -Invoke Remove-ItemProperty -ModuleName ERAZER.RemoteControl -Times 1 -Exactly -ParameterFilter { $LiteralPath -eq $registryKey -and $Name -eq 'ProxyServer' }
            Should -Invoke Add-Type -ModuleName ERAZER.RemoteControl -Times 0 -Exactly
        }

        It 'preserves the original write failure even if rollback also fails' {
            Mock Set-ItemProperty -ModuleName ERAZER.RemoteControl { throw 'Unexpected registry write' }
            Mock Set-ItemProperty -ModuleName ERAZER.RemoteControl {} -ParameterFilter { $Name -eq 'ProxyServer' -and $Value -eq 'new:7897' }
            Mock Set-ItemProperty -ModuleName ERAZER.RemoteControl { throw 'synthetic original write denied' } -ParameterFilter { $Name -eq 'ProxyOverride' }
            Mock Set-ItemProperty -ModuleName ERAZER.RemoteControl { throw 'synthetic rollback denied' } -ParameterFilter { $Name -eq 'ProxyServer' -and $Value -eq 'old:7897' }
            Mock Write-Warning -ModuleName ERAZER.RemoteControl {}
            { Set-WinInetProxy -On $true -Server 'new:7897' } | Should -Throw '*original write denied*'
            Should -Invoke Write-Warning -ModuleName ERAZER.RemoteControl -Times 1 -Exactly -ParameterFilter { $Message -like '*rollback*ProxyServer*' }
            Should -Invoke Add-Type -ModuleName ERAZER.RemoteControl -Times 0 -Exactly
        }

        It 'does not report disabled if the ProxyEnable DWORD write fails' {
            $oldProxy.ProxyEnable = 1
            Mock Set-ItemProperty -ModuleName ERAZER.RemoteControl { throw 'synthetic disable denied' }
            { Set-WinInetProxy -On $false } | Should -Throw '*disable denied*'
            Should -Invoke Set-ItemProperty -ModuleName ERAZER.RemoteControl -Times 1 -Exactly -ParameterFilter { $Name -eq 'ProxyEnable' -and $Value -eq 0 -and $Type -eq 'DWord' }
            Should -Invoke Add-Type -ModuleName ERAZER.RemoteControl -Times 0 -Exactly
        }
    }

    Context 'WinHTTP native return code handling through a mocked command seam' {
        AfterEach {
            & (Get-Module ERAZER.RemoteControl) { Remove-Variable LASTEXITCODE -Scope Script -ErrorAction SilentlyContinue }
        }

        It 'WhatIf launches zero netsh commands for enable and disable' {
            Set-WinHttpProxy -On $true -Server 'new:7897' -WhatIf
            Set-WinHttpProxy -On $false -WhatIf
            Should -Invoke netsh.exe -ModuleName ERAZER.RemoteControl -Times 0 -Exactly
            Should -Invoke Start-Process -ModuleName ERAZER.RemoteControl -Times 0 -Exactly
        }

        It 'rejects empty enable server before any native invocation' {
            { Set-WinHttpProxy -On $true -Server '' } | Should -Throw '*server is required*'
            Should -Invoke netsh.exe -ModuleName ERAZER.RemoteControl -Times 0 -Exactly
        }

        It 'throws for nonzero native exit <Code> on <Operation> even if output appears successful' -ForEach @(
            @{ Code = 1; Operation = 'enable'; On = $true }, @{ Code = 5; Operation = 'disable'; On = $false },
            @{ Code = 87; Operation = 'enable'; On = $true }
        ) {
            & (Get-Module ERAZER.RemoteControl) { param($code) $script:LASTEXITCODE = $code } $Code
            Mock netsh.exe -ModuleName ERAZER.RemoteControl { 'Current WinHTTP proxy settings: success-looking text' }
            { Set-WinHttpProxy -On $On -Server 'new:7897' } | Should -Throw "*exit $Code*"
            Should -Invoke netsh.exe -ModuleName ERAZER.RemoteControl -Times 1 -Exactly
        }

        It 'invokes the exact enable arguments and emits no accidental success payload when exit is zero' {
            & (Get-Module ERAZER.RemoteControl) { $script:LASTEXITCODE = 0 }
            Mock netsh.exe -ModuleName ERAZER.RemoteControl { 'synthetic configured' }
            Set-WinHttpProxy -On $true -Server 'new:7897' | Should -BeNullOrEmpty
            Should -Invoke netsh.exe -ModuleName ERAZER.RemoteControl -Times 1 -Exactly -ParameterFilter {
                ($args -join '|') -ceq 'winhttp|set|proxy|proxy-server=new:7897|bypass-list=<local>;192.168.*;10.*;169.254.*'
            }
        }

        It 'uses reset proxy when disabling and checks its native return code' {
            & (Get-Module ERAZER.RemoteControl) { $script:LASTEXITCODE = 0 }
            Mock netsh.exe -ModuleName ERAZER.RemoteControl { 'synthetic direct access' }
            Set-WinHttpProxy -On $false | Should -BeNullOrEmpty
            Should -Invoke netsh.exe -ModuleName ERAZER.RemoteControl -Times 1 -Exactly -ParameterFilter { ($args -join '|') -ceq 'winhttp|reset|proxy' }
        }
    }
}

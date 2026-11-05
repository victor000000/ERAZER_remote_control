# Pester 5.7.1. HTTP, process enumeration/launch and sleeps are mocked fail-closed.
BeforeAll {
    $modulePath = Join-Path $PSScriptRoot '../../src/ERAZER.RemoteControl/ERAZER.RemoteControl.psd1'
    Import-Module $modulePath -Force -ErrorAction Stop
    $readyStatus = @'
Status of project Synthetic
Strategies generated 1,234
Accepted 12.5 %
Rejected 87.5 %
Failed 7
Strategies per hour 2,345.67
Accepted strategies per hour 123.45
In databank 42
Running time so far 01:02:03
'@

    function New-FakeSqxProcess {
        param($ExitCode = 0, [switch]$DenyPriority, [switch]$FailWait, [switch]$FailRefresh)
        $fake = [pscustomobject]@{
            ExitCode = $ExitCode; WaitCalls = 0; RefreshCalls = 0; DisposeCalls = 0
            PriorityValue = ''; DenyPriority = [bool]$DenyPriority; FailWait = [bool]$FailWait; FailRefresh = [bool]$FailRefresh
        }
        $fake | Add-Member ScriptProperty PriorityClass { $this.PriorityValue } {
            param($value)
            if ($this.DenyPriority) { throw [UnauthorizedAccessException]::new('synthetic priority denied') }
            $this.PriorityValue = $value
        }
        $fake | Add-Member ScriptMethod WaitForExit {
            $this.WaitCalls++
            if ($this.FailWait) { throw 'synthetic wait failed' }
        }
        $fake | Add-Member ScriptMethod Refresh {
            $this.RefreshCalls++
            if ($this.FailRefresh) { throw 'synthetic refresh failed' }
        }
        $fake | Add-Member ScriptMethod Dispose { $this.DisposeCalls++ }
        return $fake
    }
}

Describe 'SQX offline regression contracts' {
    BeforeEach {
        Mock Invoke-WebRequest -ModuleName ERAZER.RemoteControl { throw 'Forbidden live HTTP' }
        Mock Start-Process -ModuleName ERAZER.RemoteControl { throw 'Forbidden process launch' }
        Mock Get-Process -ModuleName ERAZER.RemoteControl { throw 'Forbidden live process query' }
        Mock Start-Sleep -ModuleName ERAZER.RemoteControl { throw 'Unexpected sleep' }
        Mock New-Object -ModuleName ERAZER.RemoteControl { throw 'Forbidden object creation' }
        Mock Get-ItemProperty -ModuleName ERAZER.RemoteControl { throw 'Forbidden registry read' }
        Mock Set-ItemProperty -ModuleName ERAZER.RemoteControl { throw 'Forbidden registry write' }
        Mock Add-Type -ModuleName ERAZER.RemoteControl { throw 'Forbidden native type loading' }
        Mock Import-PowerShellDataFile -ModuleName ERAZER.RemoteControl { throw 'Forbidden config read' }
    }

    Context 'Project command grammar' {
        It 'constructs action <Action> without a task suffix' -ForEach @(
            @{ Action = 'status' }, @{ Action = 'start' }, @{ Action = 'stop' }, @{ Action = 'pause' }, @{ Action = 'resume' }
        ) {
            New-SqxProjectCommand -Action $Action -Project 'Synthetic & Project' -Task 9 |
                Should -BeExactly ('-project action=' + $Action + ' name="Synthetic & Project"')
        }

        It 'constructs 1-based task action <Action>' -ForEach @(
            @{ Action = 'startOnlyTask' }, @{ Action = 'startFromTask' }
        ) {
            New-SqxProjectCommand -Action $Action -Project Synthetic -Task 999 |
                Should -BeExactly ('-project action=' + $Action + ' name="Synthetic" task=999')
            { New-SqxProjectCommand -Action $Action -Project Synthetic } | Should -Throw '*1-based*'
            { New-SqxProjectCommand -Action $Action -Project Synthetic -Task 0 } | Should -Throw '*1-based*'
        }

        It 'rejects invalid project <Label>' -ForEach @(
            @{ Label = 'quote injection'; Project = 'x" action=stop' }
            @{ Label = 'equals'; Project = 'x=y' }
            @{ Label = 'forward slash'; Project = 'parent/child' }
            @{ Label = 'backslash'; Project = 'parent\child' }
            @{ Label = 'current directory'; Project = '.' }
            @{ Label = 'parent directory'; Project = '..' }
            @{ Label = 'leading space'; Project = ' x' }
            @{ Label = 'trailing space'; Project = 'x ' }
            @{ Label = 'newline'; Project = "x`ny" }
            @{ Label = 'tab'; Project = "x`ty" }
            @{ Label = 'NUL'; Project = ('x' + [char]0 + 'y') }
        ) {
            { New-SqxProjectCommand -Action status -Project $Project } | Should -Throw '*project name*'
        }

        It 'rejects unknown actions, empty names and out-of-range tasks' {
            { New-SqxProjectCommand -Action erase -Project Synthetic } | Should -Throw
            { New-SqxProjectCommand -Action status -Project '' } | Should -Throw
            { New-SqxProjectCommand -Action startFromTask -Project Synthetic -Task -1 } | Should -Throw
            { New-SqxProjectCommand -Action startFromTask -Project Synthetic -Task 1000 } | Should -Throw
        }

        It 'preserves literal shell and regex characters in valid project names' {
            New-SqxProjectCommand -Action status -Project 'A & B [145] $1 + % #' |
                Should -BeExactly '-project action=status name="A & B [145] $1 + % #"'
        }
    }

    Context 'API URL encoding' {
        It 'leaves grammar equals literal but encodes ampersands, plus, quotes and spaces' {
            $command = New-SqxProjectCommand -Action startFromTask -Project 'A & B+[145] $1#%' -Task 2
            $uri = ConvertTo-SqxApiUri -ApiBase 'http://127.0.0.1:5050/' -Command $command
            $uri | Should -BeExactly 'http://127.0.0.1:5050/call?cmd=-project%20action=startFromTask%20name=%22A%20%26%20B%2B%5B145%5D%20%241%23%25%22%20task=2'
            $uri | Should -Not -Match '%3[dD]'
            $uri | Should -Not -Match '&'
            [Uri]::UnescapeDataString(($uri -split '\?cmd=', 2)[1]) | Should -BeExactly $command
        }

        It 'normalizes valid origin <Origin>' -ForEach @(
            @{ Origin = 'https://localhost:8443'; Expected = 'https://localhost:8443/call?cmd=-h' }
            @{ Origin = 'http://[::1]:5050/'; Expected = 'http://[::1]:5050/call?cmd=-h' }
        ) {
            # .NET Framework expands IPv6 while modern .NET compresses it; compare normalized URIs.
            $actual = [uri](ConvertTo-SqxApiUri -ApiBase $Origin -Command '-h')
            $actual.AbsoluteUri | Should -BeExactly ([uri]$Expected).AbsoluteUri
            $actual.PathAndQuery | Should -BeExactly '/call?cmd=-h'
        }

        It 'rejects non-origin <Origin>' -ForEach @(
            @{ Origin = 'ftp://127.0.0.1:5050' }, @{ Origin = 'http://user:pass@localhost:5050' },
            @{ Origin = 'http://localhost:5050/path' }, @{ Origin = 'http://localhost:5050/?x=y' },
            @{ Origin = 'http://localhost:5050/#frag' }, @{ Origin = '/relative' }, @{ Origin = 'not a uri' }
        ) {
            { ConvertTo-SqxApiUri -ApiBase $Origin -Command '-h' } | Should -Throw '*HTTP(S) origin*'
            Should -Invoke Invoke-WebRequest -ModuleName ERAZER.RemoteControl -Times 0 -Exactly
        }

        It 'rejects blank or multiline command <Label>' -ForEach @(
            @{ Label = 'blank'; Command = '  ' }, @{ Label = 'CR'; Command = "-h`r" },
            @{ Label = 'LF'; Command = "-h`n" }, @{ Label = 'NUL'; Command = ('-h' + [char]0) }
        ) {
            { ConvertTo-SqxApiUri -Command $Command } | Should -Throw '*command*'
        }
    }

    Context 'HTTP 200 is not sufficient evidence of success' {
        It 'rejects payload <Label>' -ForEach @(
            @{ Label = 'empty'; Content = '' }, @{ Label = 'whitespace'; Content = '  ' },
            @{ Label = 'CLI not ready'; Content = 'CLI not ready, retry later' },
            @{ Label = 'embedded not ready'; Content = "header`nCLI not ready" },
            @{ Label = 'Error line'; Content = "header`n Error: no project" },
            @{ Label = 'unrecognized command'; Content = 'Unrecognized command: -x' },
            @{ Label = 'unrecognized action'; Content = 'Unrecognized action: x' },
            @{ Label = 'resolution error'; Content = 'Unable to resolve project' },
            @{ Label = 'HTML'; Content = ' <html><body>proxy failure</body></html>' },
            @{ Label = 'DOCTYPE'; Content = '<!DOCTYPE html><title>Login</title>' }
        ) {
            Test-SqxResponse -Content $Content | Should -BeFalse
            Mock Invoke-WebRequest -ModuleName ERAZER.RemoteControl { [pscustomobject]@{ StatusCode = 200; Content = $Content } }
            { Invoke-SqxRequest -Command '-h' } | Should -Throw '*error or a not-ready response*'
        }

        It 'requires ready status markers and help usage while allowing command acknowledgments' {
            Test-SqxResponse $readyStatus -Kind Status | Should -BeTrue
            Test-SqxResponse 'Status of project Synthetic' -Kind Status | Should -BeFalse
            Test-SqxResponse 'Strategies generated 5' -Kind Status | Should -BeFalse
            Test-SqxResponse "Usage: sqcli [options]`nhelp" -Kind Help | Should -BeTrue
            Test-SqxResponse 'OK' -Kind Help | Should -BeFalse
            Test-SqxResponse 'Project started' -Kind Command | Should -BeTrue
        }

        It 'passes bounded timeout and encoded command to the mocked HTTP seam and returns content only' {
            Mock Invoke-WebRequest -ModuleName ERAZER.RemoteControl { [pscustomobject]@{ StatusCode = 200; Content = 'Project started' } }
            Invoke-SqxRequest -Command '-project action=start name="A & B"' -ApiBase 'http://127.0.0.1:5050' -TimeoutSec 7 |
                Should -BeExactly 'Project started'
            Should -Invoke Invoke-WebRequest -ModuleName ERAZER.RemoteControl -Times 1 -Exactly -ParameterFilter {
                $Uri -ceq 'http://127.0.0.1:5050/call?cmd=-project%20action=start%20name=%22A%20%26%20B%22' -and
                $UseBasicParsing -and $TimeoutSec -eq 7 -and $ErrorAction -eq 'Stop'
            }
        }

        It 'propagates transport failures and validates timeout before HTTP' {
            Mock Invoke-WebRequest -ModuleName ERAZER.RemoteControl { throw 'synthetic transport failure' }
            { Invoke-SqxRequest -Command '-h' } | Should -Throw '*synthetic transport failure*'
            { Invoke-SqxRequest -Command '-h' -TimeoutSec 0 } | Should -Throw
            { Invoke-SqxRequest -Command '-h' -TimeoutSec 301 } | Should -Throw
            Should -Invoke Invoke-WebRequest -ModuleName ERAZER.RemoteControl -Times 1 -Exactly
        }
    }

    Context 'Project-wide status parsing' {
        It 'parses invariant numeric labels, percentages and runtime with CRLF' {
            $result = ConvertFrom-SqxStatus ($readyStatus -replace '\r?\n', "`r`n")
            $result.Generated | Should -Be 1234
            $result.AcceptedPercent | Should -Be 12.5
            $result.RejectedPercent | Should -Be 87.5
            $result.Failed | Should -Be 7
            $result.GeneratedPerHour | Should -Be 2345.67
            $result.AcceptedPerHour | Should -Be 123.45
            $result.ProjectDatabankCount | Should -Be 42
            $result.Runtime | Should -BeExactly '01:02:03'
        }

        It 'does not mistake task/databank sublabels for project-wide In databank' {
            $content = "Status of project Synthetic`nStrategies generated 0`nTask 1 In databank 999`n  In databank 888`nIn databank 17`nAccepted strategies per hour 3`nStrategies per hour 11`n"
            $result = ConvertFrom-SqxStatus $content
            $result.ProjectDatabankCount | Should -Be 17
            $result.GeneratedPerHour | Should -Be 11
            $result.AcceptedPerHour | Should -Be 3
        }

        It 'returns null for absent optional metrics rather than inventing zeroes' {
            $result = ConvertFrom-SqxStatus "Status of project Synthetic`nStrategies generated 0`nTask 1 In databank 123"
            $result.Generated | Should -Be 0
            foreach ($property in @('AcceptedPercent', 'RejectedPercent', 'Failed', 'GeneratedPerHour', 'AcceptedPerHour', 'ProjectDatabankCount')) {
                $result.$property | Should -BeNullOrEmpty
            }
            $result.Runtime | Should -BeExactly ''
        }

        It 'parses using invariant culture even when the current culture uses decimal commas' {
            $previous = [Threading.Thread]::CurrentThread.CurrentCulture
            try {
                [Threading.Thread]::CurrentThread.CurrentCulture = [Globalization.CultureInfo]::GetCultureInfo('de-DE')
                (ConvertFrom-SqxStatus $readyStatus).GeneratedPerHour | Should -Be 2345.67
            } finally { [Threading.Thread]::CurrentThread.CurrentCulture = $previous }
        }

        It 'rejects unready, HTML and malformed status bodies' {
            foreach ($content in @('CLI not ready', '<html>error</html>', 'Status of project Synthetic', 'OK')) {
                { ConvertFrom-SqxStatus $content } | Should -Throw '*not a ready*'
            }
        }
    }

    Context 'Bounded readiness polling without live requests or real Start-Sleep' {
        It 'returns immediately when the first response is ready' {
            Mock Invoke-SqxRequest -ModuleName ERAZER.RemoteControl { $readyStatus }
            $result = Wait-SqxReady -Project Synthetic -TimeoutSec 10
            $result.Generated | Should -Be 1234
            Should -Invoke Invoke-SqxRequest -ModuleName ERAZER.RemoteControl -Times 1 -Exactly -ParameterFilter {
                $Command -ceq '-project action=status name="Synthetic"' -and $TimeoutSec -ge 1 -and $TimeoutSec -le 5
            }
            Should -Invoke Start-Sleep -ModuleName ERAZER.RemoteControl -Times 0 -Exactly
        }

        It 'retries transport failure, not-ready content and incomplete status before succeeding' {
            $script:readyAttempts = 0
            Mock Invoke-SqxRequest -ModuleName ERAZER.RemoteControl {
                $script:readyAttempts++
                switch ($script:readyAttempts) {
                    1 { throw 'synthetic temporary connection failure' }
                    2 { return 'CLI not ready' }
                    3 { return 'Status of project Synthetic' }
                    default { return $readyStatus }
                }
            }
            Mock Start-Sleep -ModuleName ERAZER.RemoteControl {}
            $result = Wait-SqxReady -Project Synthetic -ApiBase 'http://127.0.0.1:5051' -TimeoutSec 10 -PollIntervalMilliseconds 7
            $result.Generated | Should -Be 1234
            Should -Invoke Invoke-SqxRequest -ModuleName ERAZER.RemoteControl -Times 4 -Exactly -ParameterFilter {
                $ApiBase -eq 'http://127.0.0.1:5051' -and $TimeoutSec -ge 1 -and $TimeoutSec -le 5
            }
            Should -Invoke Start-Sleep -ModuleName ERAZER.RemoteControl -Times 3 -Exactly -ParameterFilter { $Milliseconds -gt 0 -and $Milliseconds -le 7 }
        }

        It 'throws the real readiness timeout after one synthetic request consumes the one-second deadline' {
            # The production clock is static Stopwatch; emulate one slow request with a bounded local event wait.
            # No Start-Sleep, HTTP or timer thread is started, and exactly one request is permitted.
            $script:timeoutAttempts = 0
            Mock Invoke-SqxRequest -ModuleName ERAZER.RemoteControl {
                $script:timeoutAttempts++
                if ($script:timeoutAttempts -gt 1) { throw 'Readiness retry exceeded the test bound' }
                $gate = [Threading.ManualResetEvent]::new($false)
                try { $null = $gate.WaitOne(1100) } finally { $gate.Dispose() }
                throw 'synthetic unavailable'
            }
            Mock Start-Sleep -ModuleName ERAZER.RemoteControl { throw 'Deadline already elapsed; must not sleep' }
            { Wait-SqxReady -Project Synthetic -TimeoutSec 1 -PollIntervalMilliseconds 10000 } |
                Should -Throw '*did not become ready within 1 seconds*' -ExceptionType ([TimeoutException])
            Should -Invoke Invoke-SqxRequest -ModuleName ERAZER.RemoteControl -Times 1 -Exactly -ParameterFilter { $TimeoutSec -eq 1 }
            Should -Invoke Start-Sleep -ModuleName ERAZER.RemoteControl -Times 0 -Exactly
        }

        It 'rejects invalid polling bounds before any request' {
            Mock Invoke-SqxRequest -ModuleName ERAZER.RemoteControl { throw 'Unexpected request' }
            { Wait-SqxReady -Project Synthetic -TimeoutSec 0 } | Should -Throw
            { Wait-SqxReady -Project Synthetic -TimeoutSec 601 } | Should -Throw
            { Wait-SqxReady -Project Synthetic -PollIntervalMilliseconds 0 } | Should -Throw
            { Wait-SqxReady -Project Synthetic -PollIntervalMilliseconds 10001 } | Should -Throw
            { Wait-SqxReady -Project 'bad=name' } | Should -Throw
            Should -Invoke Invoke-SqxRequest -ModuleName ERAZER.RemoteControl -Times 0 -Exactly
        }
    }

    Context 'Engine native result and resource lifecycle with fake processes only' {
        BeforeEach {
            $installDirectory = Join-Path $TestDrive 'SQX [synthetic]'
            $logDirectory = Join-Path $TestDrive 'logs [synthetic]'
            $null = New-Item -ItemType Directory -Path $installDirectory -Force
            $executable = Join-Path $installDirectory 'sqcli.exe'
            Set-Content -LiteralPath $executable -Value 'not executable; never launch'
            Mock Get-Process -ModuleName ERAZER.RemoteControl {}
            Mock New-Item -ModuleName ERAZER.RemoteControl { [pscustomobject]@{ FullName = $logDirectory } }
            $fakeProcess = New-FakeSqxProcess
            Mock Start-Process -ModuleName ERAZER.RemoteControl { $fakeProcess }
        }

        It 'preserves native exit code <ExitCode>, waits, refreshes and disposes exactly once' -ForEach @(
            @{ ExitCode = 0 }, @{ ExitCode = 1 }, @{ ExitCode = 42 }, @{ ExitCode = -1073741510 }
        ) {
            $fakeProcess = New-FakeSqxProcess -ExitCode $ExitCode
            $result = Invoke-SqxEngine -InstallDirectory $installDirectory -LogDirectory $logDirectory -Project 'A & B [145]' -Task 2
            $result | Should -BeOfType ([int])
            $result | Should -Be $ExitCode
            $fakeProcess.WaitCalls | Should -Be 1
            $fakeProcess.RefreshCalls | Should -Be 1
            $fakeProcess.DisposeCalls | Should -Be 1
            $fakeProcess.PriorityValue | Should -Be 'High'
            Should -Invoke Start-Process -ModuleName ERAZER.RemoteControl -Times 1 -Exactly -ParameterFilter {
                $FilePath -eq $executable -and $WorkingDirectory -eq $installDirectory -and
                $ArgumentList -ceq '"-project" "action=startFromTask" "name=A & B [145]" "task=2"' -and
                $WindowStyle -eq 'Hidden' -and $PassThru -and $ErrorAction -eq 'Stop' -and
                $RedirectStandardOutput.StartsWith($logDirectory) -and $RedirectStandardOutput.EndsWith('.stdout.log') -and
                $RedirectStandardError.StartsWith($logDirectory) -and $RedirectStandardError.EndsWith('.stderr.log') -and
                $RedirectStandardOutput -ne $RedirectStandardError
            }
        }

        It 'does not let priority access denial replace the native exit result' {
            $fakeProcess = New-FakeSqxProcess -ExitCode 73 -DenyPriority
            Invoke-SqxEngine -InstallDirectory $installDirectory -LogDirectory $logDirectory -Project Synthetic | Should -Be 73
            $fakeProcess.WaitCalls | Should -Be 1
            $fakeProcess.RefreshCalls | Should -Be 1
            $fakeProcess.DisposeCalls | Should -Be 1
        }

        It 'reads ExitCode only after WaitForExit and Refresh' {
            $fakeProcess = New-FakeSqxProcess
            $fakeProcess.PSObject.Properties.Remove('ExitCode')
            $fakeProcess | Add-Member ScriptProperty ExitCode {
                if ($this.WaitCalls -ne 1 -or $this.RefreshCalls -ne 1) { throw 'exit read too early' }
                return 27
            }
            Invoke-SqxEngine -InstallDirectory $installDirectory -LogDirectory $logDirectory -Project Synthetic | Should -Be 27
            $fakeProcess.DisposeCalls | Should -Be 1
        }

        It 'disposes and fails rather than converting unreadable null exit code to success' {
            $fakeProcess = New-FakeSqxProcess -ExitCode $null
            { Invoke-SqxEngine -InstallDirectory $installDirectory -LogDirectory $logDirectory -Project Synthetic } |
                Should -Throw '*exit code could not be read*'
            $fakeProcess.DisposeCalls | Should -Be 1
        }

        It 'disposes after a failing <Stage>' -ForEach @(
            @{ Stage = 'WaitForExit' }, @{ Stage = 'Refresh' }
        ) {
            $fakeProcess = New-FakeSqxProcess -FailWait:($Stage -eq 'WaitForExit') -FailRefresh:($Stage -eq 'Refresh')
            { Invoke-SqxEngine -InstallDirectory $installDirectory -LogDirectory $logDirectory -Project Synthetic } | Should -Throw '*synthetic*failed*'
            $fakeProcess.DisposeCalls | Should -Be 1
        }

        It 'rejects duplicate SQX processes before creating logs or launching' {
            Mock Get-Process -ModuleName ERAZER.RemoteControl { [pscustomobject]@{ Id = 123; ProcessName = 'sqcli' } }
            { Invoke-SqxEngine -InstallDirectory $installDirectory -LogDirectory $logDirectory -Project Synthetic } | Should -Throw '*duplicate launch*'
            Should -Invoke Start-Process -ModuleName ERAZER.RemoteControl -Times 0 -Exactly
            Should -Invoke New-Item -ModuleName ERAZER.RemoteControl -Times 0 -Exactly
        }

        It 'rejects missing executable before process enumeration or launch' {
            Remove-Item -LiteralPath $executable
            { Invoke-SqxEngine -InstallDirectory $installDirectory -LogDirectory $logDirectory -Project Synthetic } | Should -Throw '*executable not found*'
            Should -Invoke Get-Process -ModuleName ERAZER.RemoteControl -Times 0 -Exactly
            Should -Invoke Start-Process -ModuleName ERAZER.RemoteControl -Times 0 -Exactly
        }

        It 'WhatIf performs zero process queries, launches or directory writes' {
            $result = Invoke-SqxEngine -InstallDirectory $installDirectory -LogDirectory $logDirectory -Project Synthetic -WhatIf
            $result | Should -BeNullOrEmpty
            Should -Invoke Start-Process -ModuleName ERAZER.RemoteControl -Times 0 -Exactly
            Should -Invoke Get-Process -ModuleName ERAZER.RemoteControl -Times 0 -Exactly
            Should -Invoke New-Item -ModuleName ERAZER.RemoteControl -Times 0 -Exactly
            $fakeProcess.WaitCalls | Should -Be 0
            $fakeProcess.DisposeCalls | Should -Be 0
        }

        It 'fails closed when log directory creation or process launch fails' {
            Mock New-Item -ModuleName ERAZER.RemoteControl { throw 'synthetic log directory denied' }
            { Invoke-SqxEngine -InstallDirectory $installDirectory -LogDirectory $logDirectory -Project Synthetic } | Should -Throw '*directory denied*'
            Should -Invoke Start-Process -ModuleName ERAZER.RemoteControl -Times 0 -Exactly
            Mock New-Item -ModuleName ERAZER.RemoteControl {}
            Mock Start-Process -ModuleName ERAZER.RemoteControl { throw 'synthetic launch denied' }
            { Invoke-SqxEngine -InstallDirectory $installDirectory -LogDirectory $logDirectory -Project Synthetic } | Should -Throw '*launch denied*'
            $fakeProcess.DisposeCalls | Should -Be 0
        }
    }
}

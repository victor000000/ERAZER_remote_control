# Pester 5.7.1. Only synthetic TestDrive files are read; all operational seams fail closed.
BeforeAll {
    $modulePath = Join-Path $PSScriptRoot '../../src/ERAZER.RemoteControl/ERAZER.RemoteControl.psd1'
    Import-Module $modulePath -Force -ErrorAction Stop

    function New-CoreConfigFixture {
        param([string]$Path, [string]$Change = '')
        $text = @'
@{
    SchemaVersion = 1
    Target = @{ SshAlias = 'offline'; Nested = @{ First = 'base'; Second = 'keep' } }
    Sqx = @{
        InstallDirectory = 'X:\synthetic\SQX [145]'
        Project = 'Synthetic & Project'
        ApiBase = 'http://127.0.0.1:5050'
        TaskName = 'SyntheticHeadless'
        GuiTaskName = 'SyntheticGui'
        LogDirectory = 'X:\synthetic\logs'
    }
    Proxy = @{ FailureThreshold = 3; UnknownThreshold = 3; Servers = @{ HypoMux = '<gateway>:7897' } }
    Controller = @{ ExpectedTasks = @('One', 'Two') }
}
'@
        if ($Change) { $text = & ([scriptblock]::Create($Change)) $text }
        Set-Content -LiteralPath $Path -Value $text -Encoding UTF8
        return $Path
    }
}

Describe 'Core offline regression contracts' {
    BeforeEach {
        Mock New-Object -ModuleName ERAZER.RemoteControl { throw 'Forbidden object creation in offline tests' }
        Mock Start-Process -ModuleName ERAZER.RemoteControl { throw 'Forbidden process launch' }
        Mock Get-Process -ModuleName ERAZER.RemoteControl { throw 'Forbidden live process query' }
        Mock Invoke-WebRequest -ModuleName ERAZER.RemoteControl { throw 'Forbidden HTTP request' }
        Mock Get-ItemProperty -ModuleName ERAZER.RemoteControl { throw 'Forbidden registry read' }
        Mock Set-ItemProperty -ModuleName ERAZER.RemoteControl { throw 'Forbidden registry write' }
        Mock Add-Type -ModuleName ERAZER.RemoteControl { throw 'Forbidden native type loading' }
        $fixturePath = Join-Path $TestDrive ('defaults [fixture]-' + [guid]::NewGuid().ToString('N') + '.psd1')
        $localFixturePath = Join-Path $TestDrive ('explicit-' + [guid]::NewGuid().ToString('N') + '.local.psd1')
        Mock Import-PowerShellDataFile -ModuleName ERAZER.RemoteControl {
            throw 'Forbidden non-fixture config read'
        } -ParameterFilter { -not $LiteralPath.StartsWith($TestDrive, [StringComparison]::OrdinalIgnoreCase) }
    }

    Context 'Explicit configuration files and recursive merging' {
        It 'validates an explicit fixture without implicitly reading a local config' {
            $null = New-CoreConfigFixture $fixturePath
            Set-Content -LiteralPath $localFixturePath -Value "@{ Sqx = @{ Project = 'MUST NOT LOAD' } }"
            $result = Get-ToolkitConfig -Path $fixturePath
            $result.Sqx.Project | Should -BeExactly 'Synthetic & Project'
            $result.Controller.ExpectedTasks | Should -Be @('One', 'Two')
            Should -Invoke Import-PowerShellDataFile -ModuleName ERAZER.RemoteControl -Times 0 -Exactly
        }

        It 'merges only an explicitly requested local fixture, recursively retaining siblings' {
            $null = New-CoreConfigFixture $fixturePath
            Set-Content -LiteralPath $localFixturePath -Value @'
@{
    Target = @{ Nested = @{ First = 'override'; Third = 'new' } }
    Sqx = @{ Project = 'Local Project' }
    Proxy = @{ Servers = @{ Additional = '127.0.0.2:7897' } }
    Controller = @{ ExpectedTasks = @('Replacement') }
    Extension = @{ Enabled = $true }
}
'@
            $result = Get-ToolkitConfig -Path $fixturePath -LocalPath $localFixturePath
            $result.Target.SshAlias | Should -Be 'offline'
            $result.Target.Nested.First | Should -Be 'override'
            $result.Target.Nested.Second | Should -Be 'keep'
            $result.Target.Nested.Third | Should -Be 'new'
            $result.Sqx.Project | Should -Be 'Local Project'
            $result.Sqx.TaskName | Should -Be 'SyntheticHeadless'
            $result.Proxy.Servers.HypoMux | Should -Be '<gateway>:7897'
            $result.Proxy.Servers.Additional | Should -Be '127.0.0.2:7897'
            @($result.Controller.ExpectedTasks).Count | Should -Be 1
            $result.Controller.ExpectedTasks[0] | Should -Be 'Replacement'
            $result.Extension.Enabled | Should -BeTrue
        }

        It 'returns independent nested config objects on repeated reads' {
            $null = New-CoreConfigFixture $fixturePath
            $first = Get-ToolkitConfig -Path $fixturePath
            $first.Target.Nested.Second = 'mutated'
            $second = Get-ToolkitConfig -Path $fixturePath
            $second.Target.Nested.Second | Should -Be 'keep'
        }

        It 'rejects missing explicitly requested defaults or local files rather than silently falling back' {
            { Get-ToolkitConfig -Path $fixturePath } | Should -Throw
            $null = New-CoreConfigFixture $fixturePath
            { Get-ToolkitConfig -Path $fixturePath -LocalPath $localFixturePath } | Should -Throw
        }

        It 'rejects missing or non-hashtable required section <Section>' -ForEach @(
            @{ Section = 'Target' }, @{ Section = 'Sqx' }, @{ Section = 'Proxy' }, @{ Section = 'Controller' }
        ) {
            $null = New-CoreConfigFixture $fixturePath
            Set-Content -LiteralPath $localFixturePath -Value ("@{ $Section = 'not a table' }")
            { Get-ToolkitConfig -Path $fixturePath -LocalPath $localFixturePath } | Should -Throw '*configuration section*'
            $text = Get-Content -LiteralPath $fixturePath -Raw
            $config = [scriptblock]::Create($text).InvokeReturnAsIs()
            $config.Remove($Section)
            Mock Import-PowerShellDataFile -ModuleName ERAZER.RemoteControl { $config }
            { Get-ToolkitConfig -Path $fixturePath } | Should -Throw '*configuration section*'
        }

        It 'rejects an unsupported schema' {
            $null = New-CoreConfigFixture $fixturePath
            Set-Content -LiteralPath $localFixturePath -Value '@{ SchemaVersion = 2 }'
            { Get-ToolkitConfig -Path $fixturePath -LocalPath $localFixturePath } | Should -Throw '*schema*'
        }

        It 'rejects blank Sqx.<Key> after merging' -ForEach @(
            @{ Key = 'InstallDirectory' }, @{ Key = 'Project' }, @{ Key = 'ApiBase' },
            @{ Key = 'TaskName' }, @{ Key = 'LogDirectory' }, @{ Key = 'GuiTaskName' }
        ) {
            $null = New-CoreConfigFixture $fixturePath
            Set-Content -LiteralPath $localFixturePath -Value ("@{ Sqx = @{ $Key = '   ' } }")
            { Get-ToolkitConfig -Path $fixturePath -LocalPath $localFixturePath } | Should -Throw "*Missing Sqx.$Key*"
        }

        It 'rejects non-positive proxy <Key>' -ForEach @(
            @{ Key = 'FailureThreshold' }, @{ Key = 'UnknownThreshold' }
        ) {
            $null = New-CoreConfigFixture $fixturePath
            Set-Content -LiteralPath $localFixturePath -Value ("@{ Proxy = @{ $Key = 0 } }")
            { Get-ToolkitConfig -Path $fixturePath -LocalPath $localFixturePath } | Should -Throw '*thresholds*'
        }

        It 'validates API origins and project grammar without performing a request' {
            $null = New-CoreConfigFixture $fixturePath
            Set-Content -LiteralPath $localFixturePath -Value "@{ Sqx = @{ ApiBase = 'http://127.0.0.1:5050/path' } }"
            { Get-ToolkitConfig -Path $fixturePath -LocalPath $localFixturePath } | Should -Throw '*origin*'
            Set-Content -LiteralPath $localFixturePath -Value "@{ Sqx = @{ Project = 'bad=name' } }"
            { Get-ToolkitConfig -Path $fixturePath -LocalPath $localFixturePath } | Should -Throw '*project name*'
            Should -Invoke Invoke-WebRequest -ModuleName ERAZER.RemoteControl -Times 0 -Exactly
        }
    }

    Context 'Windows CRT argument quoting' {
        It 'quotes <Label> exactly' -ForEach @(
            @{ Label = 'empty string'; InputValue = ''; Expected = '""' }
            @{ Label = 'plain token'; InputValue = 'plain'; Expected = '"plain"' }
            @{ Label = 'spaces and brackets'; InputValue = 'C:\Program Files\SQX [145]\sqcli.exe'; Expected = '"C:\Program Files\SQX [145]\sqcli.exe"' }
            @{ Label = 'embedded quote'; InputValue = 'a"b'; Expected = '"a\"b"' }
            @{ Label = 'backslash before quote'; InputValue = 'a\"b'; Expected = '"a\\\"b"' }
            @{ Label = 'two backslashes before quote'; InputValue = 'a\\"b'; Expected = '"a\\\\\"b"' }
            @{ Label = 'trailing slash'; InputValue = 'C:\folder\'; Expected = '"C:\folder\\"' }
            @{ Label = 'trailing slash pair'; InputValue = 'C:\folder\\'; Expected = '"C:\folder\\\\"' }
            @{ Label = 'literal metacharacters'; InputValue = '$1 & a=b | ^ %PATH%'; Expected = '"$1 & a=b | ^ %PATH%"' }
            @{ Label = 'tab'; InputValue = "a`tb"; Expected = "`"a`tb`"" }
        ) {
            ConvertTo-WindowsArgument -Value $InputValue | Should -BeExactly $Expected
        }

        It 'rejects command-line control character <Code>' -ForEach @(
            @{ Code = 0 }, @{ Code = 10 }, @{ Code = 13 }
        ) {
            { ConvertTo-WindowsArgument ('prefix' + [char]$Code + 'suffix') } | Should -Throw '*NUL or newlines*'
        }
    }

    Context 'Executable parsing does not resolve or execute paths' {
        It 'parses <Label>' -ForEach @(
            @{ Label = 'empty'; Line = '  '; Exe = ''; ExpectedArguments =''; Kind = 'Empty' }
            @{ Label = 'quoted brackets'; Line = '"C:\Program Files\App [145]\tool.exe" --arg "x y"'; Exe = 'C:\Program Files\App [145]\tool.exe'; ExpectedArguments ='--arg "x y"'; Kind = 'Quoted' }
            @{ Label = 'unquoted ambiguity'; Line = 'C:\Program Files\App [145]\tool.exe --run'; Exe = 'C:\Program Files\App [145]\tool.exe'; ExpectedArguments ='--run'; Kind = 'UnquotedAmbiguous' }
            @{ Label = 'unquoted literal brackets'; Line = 'C:\App[145]\tool.exe --run'; Exe = 'C:\App[145]\tool.exe'; ExpectedArguments ='--run'; Kind = 'UnquotedPath' }
            @{ Label = 'bare executable'; Line = 'TOOL.EXE /q'; Exe = 'TOOL.EXE'; ExpectedArguments ='/q'; Kind = 'BareCommand' }
            @{ Label = 'extensionless command'; Line = 'tool --arg more'; Exe = 'tool'; ExpectedArguments ='--arg more'; Kind = 'BareCommand' }
            @{ Label = 'bare no arguments'; Line = 'tool'; Exe = 'tool'; ExpectedArguments =''; Kind = 'BareCommand' }
            @{ Label = 'script path'; Line = 'C:\Tools\start.ps1 -NoProfile'; Exe = 'C:\Tools\start.ps1'; ExpectedArguments ='-NoProfile'; Kind = 'UnquotedPath' }
            @{ Label = 'NT prefix'; Line = '\??\C:\Tools\svc.exe -service'; Exe = 'C:\Tools\svc.exe'; ExpectedArguments ='-service'; Kind = 'UnquotedPath' }
            @{ Label = 'unterminated quote'; Line = '"C:\broken.exe'; Exe = ''; ExpectedArguments =''; Kind = 'Invalid' }
            @{ Label = 'junk after closing quote'; Line = '"C:\tool.exe"junk'; Exe = ''; ExpectedArguments =''; Kind = 'Invalid' }
        ) {
            $result = ConvertFrom-WindowsCommandLine $Line
            $result.Executable | Should -BeExactly $Exe
            $result.Arguments | Should -BeExactly $ExpectedArguments
            $result.Kind | Should -BeExactly $Kind
            Should -Invoke Start-Process -ModuleName ERAZER.RemoteControl -Times 0 -Exactly
        }

        It 'expands the existing SystemRoot variable and kernel SystemRoot notation without touching the environment' {
            $root = [Environment]::GetEnvironmentVariable('SystemRoot')
            $root | Should -Not -BeNullOrEmpty
            (ConvertFrom-WindowsCommandLine '%SystemRoot%\System32\cmd.exe /c test').Executable | Should -BeExactly ($root + '\System32\cmd.exe')
            (ConvertFrom-WindowsCommandLine '\SystemRoot\System32\cmd.exe /c test').Executable | Should -BeExactly ($root + '\System32\cmd.exe')
        }
    }

    Context 'Task HRESULT classification without actual COM' {
        It 'classifies direct exception <Label>' -ForEach @(
            @{ Label = 'typed denied'; Factory = { [UnauthorizedAccessException]::new('synthetic') }; Expected = 'AccessDenied' }
            @{ Label = 'typed missing'; Factory = { [IO.FileNotFoundException]::new('synthetic') }; Expected = 'Missing' }
            @{ Label = 'HRESULT denied'; Factory = { [Runtime.InteropServices.COMException]::new('synthetic', -2147024891) }; Expected = 'AccessDenied' }
            @{ Label = 'HRESULT missing'; Factory = { [Runtime.InteropServices.COMException]::new('synthetic', -2147024894) }; Expected = 'Missing' }
            @{ Label = 'unrelated error'; Factory = { [InvalidOperationException]::new('synthetic') }; Expected = 'QueryFailed' }
        ) {
            Get-TaskQueryFailureState -Exception (& $Factory) | Should -BeExactly $Expected
        }

        It 'unwraps nested PowerShell-style errors without misclassifying denial as missing' {
            $denied = [Runtime.InteropServices.COMException]::new('synthetic denied', -2147024891)
            $wrapped = [Exception]::new('outer', [InvalidOperationException]::new('middle', $denied))
            Get-TaskQueryFailureState $wrapped | Should -BeExactly 'AccessDenied'
            $missing = [Exception]::new('outer', [IO.FileNotFoundException]::new('synthetic missing'))
            Get-TaskQueryFailureState $missing | Should -BeExactly 'Missing'
        }

        It 'returns structured <Expected> task failures using only a mocked COM constructor' -ForEach @(
            @{ Expected = 'AccessDenied'; Factory = { [Runtime.InteropServices.COMException]::new('synthetic denied', -2147024891) } }
            @{ Expected = 'Missing'; Factory = { [IO.FileNotFoundException]::new('synthetic missing') } }
            @{ Expected = 'QueryFailed'; Factory = { [InvalidOperationException]::new('synthetic failure') } }
        ) {
            $failure = & $Factory
            Mock New-Object -ModuleName ERAZER.RemoteControl { throw $failure } -ParameterFilter { $ComObject -eq 'Schedule.Service' }
            $result = Get-ToolkitTask -Name 'SyntheticOnly'
            $result.Name | Should -Be 'SyntheticOnly'
            $result.QueryState | Should -BeExactly $Expected
            $result.RunState | Should -Be 'Unknown'
            $result.Enabled | Should -BeNullOrEmpty
            $result.LastResult | Should -BeNullOrEmpty
            $result.LastRun | Should -BeNullOrEmpty
            Should -Invoke New-Object -ModuleName ERAZER.RemoteControl -Times 1 -Exactly -ParameterFilter { $ComObject -eq 'Schedule.Service' }
        }

        It 'maps a fake task state <State> to <Expected> and preserves its native last result' -ForEach @(
            @{ State = 0; Expected = 'Unknown' }, @{ State = 1; Expected = 'Disabled' },
            @{ State = 2; Expected = 'Queued' }, @{ State = 3; Expected = 'Ready' }, @{ State = 4; Expected = 'Running' }
        ) {
            $fakeTask = [pscustomobject]@{ State = $State; Enabled = $true; LastTaskResult = 267009; LastRunTime = [datetime]'2026-01-01' }
            $fakeFolder = [pscustomobject]@{ Task = $fakeTask }
            $fakeFolder | Add-Member ScriptMethod GetTask { param($name) if ($name -ne 'SyntheticOnly') { throw 'Unexpected task name' }; return $this.Task }
            $fakeScheduler = [pscustomobject]@{ Folder = $fakeFolder; Connected = $false }
            $fakeScheduler | Add-Member ScriptMethod Connect { $this.Connected = $true }
            $fakeScheduler | Add-Member ScriptMethod GetFolder { param($path) if ($path -ne '\') { throw 'Unexpected folder' }; return $this.Folder }
            Mock New-Object -ModuleName ERAZER.RemoteControl { $fakeScheduler } -ParameterFilter { $ComObject -eq 'Schedule.Service' }
            $result = Get-ToolkitTask -Name SyntheticOnly
            $fakeScheduler.Connected | Should -BeTrue
            $result.QueryState | Should -Be 'Present'
            $result.RunState | Should -Be $Expected
            $result.Enabled | Should -BeTrue
            $result.LastResult | Should -Be 267009
            $result.LastRun | Should -Be ([datetime]'2026-01-01')
        }
    }

    Context 'SQX task action paths and offline construction' {
        BeforeEach {
            $actionDirectory = Join-Path $TestDrive ('actions [' + [guid]::NewGuid().ToString('N') + ']')
            $null = New-Item -ItemType Directory -Path $actionDirectory
            $engineFixture = Join-Path $actionDirectory 'engine [synthetic].ps1'
            $configFixture = Join-Path $actionDirectory 'defaults [synthetic].psd1'
            $localConfigFixture = Join-Path $actionDirectory 'explicit [synthetic].local.psd1'
            Set-Content -LiteralPath $engineFixture -Value "throw 'This synthetic engine must never be executed'"
            Set-Content -LiteralPath $configFixture -Value 'synthetic config path only, never import'
            Set-Content -LiteralPath $localConfigFixture -Value 'synthetic local config path only, never import'
        }

        It 'resolves relative literal paths against PowerShell location, not the process working directory' {
            Mock New-HeadlessTaskAction -ModuleName ERAZER.RemoteControl {
                [pscustomobject]@{ ScriptPath = $ScriptPath; Tokens = @($Arguments) }
            }
            $processDirectory = [Environment]::CurrentDirectory
            Push-Location -LiteralPath $actionDirectory
            try {
                $result = New-SqxTaskAction -EngineScript '.\engine [synthetic].ps1' -Project 'Synthetic & Project' -Task 7 `
                    -ConfigPath '.\defaults [synthetic].psd1' -LocalConfigPath '.\explicit [synthetic].local.psd1'
            } finally { Pop-Location }
            [Environment]::CurrentDirectory | Should -BeExactly $processDirectory
            $result.ScriptPath | Should -BeExactly $engineFixture
            $result.Tokens | Should -Be @('-Task', '7', '-Project', 'Synthetic & Project', '-ConfigPath', $configFixture, '-LocalConfigPath', $localConfigFixture)
            Should -Invoke New-HeadlessTaskAction -ModuleName ERAZER.RemoteControl -Times 1 -Exactly -ParameterFilter { $ScriptPath -ceq $engineFixture }
            Should -Invoke Import-PowerShellDataFile -ModuleName ERAZER.RemoteControl -Times 0 -Exactly
            Should -Invoke Start-Process -ModuleName ERAZER.RemoteControl -Times 0 -Exactly
            Should -Invoke New-Object -ModuleName ERAZER.RemoteControl -Times 0 -Exactly
        }

        It 'uses task one by default and omits both unspecified config switches' {
            Mock New-HeadlessTaskAction -ModuleName ERAZER.RemoteControl {
                [pscustomobject]@{ ScriptPath = $ScriptPath; Tokens = @($Arguments) }
            }
            $result = New-SqxTaskAction -EngineScript $engineFixture -Project Synthetic
            $result.ScriptPath | Should -BeExactly $engineFixture
            $result.Tokens | Should -Be @('-Task', '1', '-Project', 'Synthetic')
            Should -Invoke Start-Process -ModuleName ERAZER.RemoteControl -Times 0 -Exactly
        }

        It 'accepts either optional config independently: <Parameter>' -ForEach @(
            @{ Parameter = 'ConfigPath' }, @{ Parameter = 'LocalConfigPath' }
        ) {
            Mock New-HeadlessTaskAction -ModuleName ERAZER.RemoteControl {
                [pscustomobject]@{ ScriptPath = $ScriptPath; Tokens = @($Arguments) }
            }
            $parameters = @{ EngineScript = $engineFixture; Project = 'Synthetic'; Task = 2 }
            $parameters[$Parameter] = $configFixture
            $result = New-SqxTaskAction @parameters
            $result.Tokens | Should -Be @('-Task', '2', '-Project', 'Synthetic', ('-' + $Parameter), $configFixture)
            Should -Invoke Import-PowerShellDataFile -ModuleName ERAZER.RemoteControl -Times 0 -Exactly
        }

        It 'produces the actual quoted headless action without querying or creating a task' {
            $result = New-SqxTaskAction -EngineScript $engineFixture -Project 'A & B $1' -Task 999 -ConfigPath $configFixture -LocalConfigPath $localConfigFixture
            $expectedTokens = @('C:\Program Files\PowerShell\7\pwsh.exe', '-NoProfile', '-NonInteractive', '-ExecutionPolicy', 'Bypass', '-File', $engineFixture,
                '-Task', '999', '-Project', 'A & B $1', '-ConfigPath', $configFixture, '-LocalConfigPath', $localConfigFixture)
            $expectedArguments = '--headless ' + (($expectedTokens | ForEach-Object { ConvertTo-WindowsArgument $_ }) -join ' ')
            $result.Execute | Should -Be (Join-Path $env:SystemRoot 'System32/conhost.exe')
            $result.Arguments | Should -BeExactly $expectedArguments
            Should -Invoke Start-Process -ModuleName ERAZER.RemoteControl -Times 0 -Exactly
            Should -Invoke New-Object -ModuleName ERAZER.RemoteControl -Times 0 -Exactly
            Should -Invoke Import-PowerShellDataFile -ModuleName ERAZER.RemoteControl -Times 0 -Exactly
        }

        It 'rejects a missing <Parameter> path before constructing a task action' -ForEach @(
            @{ Parameter = 'EngineScript' }, @{ Parameter = 'ConfigPath' }, @{ Parameter = 'LocalConfigPath' }
        ) {
            Mock New-HeadlessTaskAction -ModuleName ERAZER.RemoteControl { throw 'Must not construct an action for nonexistent paths' }
            $parameters = @{ EngineScript = $engineFixture; Project = 'Synthetic'; ConfigPath = $configFixture; LocalConfigPath = $localConfigFixture }
            $parameters[$Parameter] = Join-Path $actionDirectory 'missing [literal].ps1'
            { New-SqxTaskAction @parameters } | Should -Throw
            Should -Invoke New-HeadlessTaskAction -ModuleName ERAZER.RemoteControl -Times 0 -Exactly
            Should -Invoke Start-Process -ModuleName ERAZER.RemoteControl -Times 0 -Exactly
        }

        It 'validates task bounds and project traversal before resolving paths or creating actions' {
            Mock New-HeadlessTaskAction -ModuleName ERAZER.RemoteControl { throw 'Unexpected action construction' }
            Mock Resolve-Path -ModuleName ERAZER.RemoteControl { throw 'Unexpected path resolution' }
            foreach ($project in @('.', '..', 'parent/child', 'parent\child')) {
                { New-SqxTaskAction -EngineScript $engineFixture -Project $project } | Should -Throw '*project name*'
            }
            { New-SqxTaskAction -EngineScript $engineFixture -Project Synthetic -Task 0 } | Should -Throw
            { New-SqxTaskAction -EngineScript $engineFixture -Project Synthetic -Task 1000 } | Should -Throw
            Should -Invoke Resolve-Path -ModuleName ERAZER.RemoteControl -Times 0 -Exactly
            Should -Invoke New-HeadlessTaskAction -ModuleName ERAZER.RemoteControl -Times 0 -Exactly
            Should -Invoke Start-Process -ModuleName ERAZER.RemoteControl -Times 0 -Exactly
        }
    }

    Context 'Headless task action construction' {
        It 'uses conhost headless and explicitly quotes every PowerShell token' {
            $result = New-HeadlessTaskAction -PowerShellPath 'X:\Program Files\pwsh.exe' -ScriptPath 'X:\Scripts [test]\run.ps1' -Arguments @('-Project', 'A & B', '', 'X:\logs\')
            $result.Execute | Should -Be (Join-Path $env:SystemRoot 'System32/conhost.exe')
            $result.Arguments | Should -BeExactly '--headless "X:\Program Files\pwsh.exe" "-NoProfile" "-NonInteractive" "-ExecutionPolicy" "Bypass" "-File" "X:\Scripts [test]\run.ps1" "-Project" "A & B" "" "X:\logs\\"'
            Should -Invoke New-Object -ModuleName ERAZER.RemoteControl -Times 0 -Exactly
            Should -Invoke Start-Process -ModuleName ERAZER.RemoteControl -Times 0 -Exactly
        }

        It 'rejects unsafe script tokens before any task interaction' {
            { New-HeadlessTaskAction -ScriptPath "X:\bad`nrun.ps1" } | Should -Throw '*NUL or newlines*'
            Should -Invoke New-Object -ModuleName ERAZER.RemoteControl -Times 0 -Exactly
        }
    }
}

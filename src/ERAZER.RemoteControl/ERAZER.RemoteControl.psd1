@{
    RootModule = 'ERAZER.RemoteControl.psm1'
    ModuleVersion = '1.0.0'
    GUID = '9dba2cf6-eeb5-4d96-8f88-5b329df1afcc'
    Author = 'ERAZER Remote Control contributors'
    Description = 'Testable configuration, SQX, proxy and Windows task helpers. Import has no operational side effects.'
    PowerShellVersion = '5.1'
    FunctionsToExport = @(
        'Get-ToolkitConfig', 'ConvertTo-WindowsArgument', 'ConvertFrom-WindowsCommandLine',
        'Get-TaskQueryFailureState', 'Get-ToolkitTask', 'New-HeadlessTaskAction', 'New-SqxTaskAction',
        'New-SqxProjectCommand', 'ConvertTo-SqxApiUri', 'Test-SqxResponse',
        'ConvertFrom-SqxStatus', 'Invoke-SqxRequest', 'Wait-SqxReady', 'Invoke-SqxEngine',
        'Get-ProxyDecision', 'Set-IniSectionValue', 'Test-ProxyEndpoint',
        'Set-WinInetProxy', 'Set-WinHttpProxy', 'New-SqxProjectArchive'
    )
    CmdletsToExport = @()
    VariablesToExport = @()
    AliasesToExport = @()
    PrivateData = @{ PSData = @{ Tags = @('Windows', 'SQX', 'RemoteControl') } }
}

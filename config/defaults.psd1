@{
    SchemaVersion = 1
    Target = @{
        SshAlias = 'erazer-hotspot'
        HostName = 'ERAZER-6JMHAKCD'
        User = 'Vic'
        LanAddress = '192.168.137.37'
        DeployRoot = 'C:\Users\Vic\ERAZER-Tools'
    }
    Sqx = @{
        InstallDirectory = 'C:\StrategyQuantX145'
        Project = 'S001_reproduce_project'
        ApiBase = 'http://127.0.0.1:5050'
        TaskName = 'SQX-Task1-Headless'
        GuiTaskName = 'StartTradingAppsAtLogon'
        LogDirectory = 'C:\Users\Vic\ERAZER-Tools\Logs'
    }
    Proxy = @{
        Servers = @{
            HypoMux = '<gateway>:7897'
            'MiFi-1A8F' = '192.168.1.100:7897'
            # JD USB is excluded due to overheating; its former controller IP is not valid.
            'MiFi706425-5G' = ''
        }
        FailureThreshold = 3
        UnknownThreshold = 3
        Mt5Directory = 'C:\MetaTrader 5 IC Markets Global'
    }
    Controller = @{
        ExpectedTasks = @('MihomoSplitter', 'OMRGatewayBoot', 'NetDashCollector', 'NetDashServer')
        MihomoRegistrar = 'C:\Users\victo\mihomo\src\setup\Register-AllTasks.ps1'
    }
}

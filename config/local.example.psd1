@{
    # Pass this file explicitly with -LocalConfigPath after copying to local.psd1.
    Target = @{
        LanAddress = '192.168.0.5'
    }
    Sqx = @{
        InstallDirectory = 'C:\StrategyQuantX145'
        Project = 'S001_reproduce_project'
    }
}

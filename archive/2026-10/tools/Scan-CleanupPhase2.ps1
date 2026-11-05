$ProgressPreference = 'SilentlyContinue'
$ErrorActionPreference = 'Continue'
function W([string]$t) { Write-Output $t }

W '--- APPX NAMES (all) ---'
Get-AppxPackage -ErrorAction SilentlyContinue | Sort-Object Name |
    ForEach-Object { W ($_.Name + ' ' + $_.Version) }

W '--- STORE GAME-LIKE APPX ---'
$gamePat = 'Solitaire|Mahjong|Minecraft|Roblox|Forza|Halo|Gears|SeaOfThieves|AgeOfEmpires|FlightSim|Candy|Zynga|King\.|Playtika|GameHouse|BigFish|WildTangent|Disney|Marvel|StarWars|Bubble|Tetris|Chess|Sudoku|Bingo|Casino|Farm|Vegas|Asphalt|UNO|Risk|Scrabble|Monopoly|Trivia|Word|Jigsaw|Hidden|Minesweeper|Hearts|Spades|Backgammon|Dominoes|Pool|Golf|Bowling|Darts|Arcade|Retro|Classic|Pinball|Saga|Blast|Crush|Puzzle|Match|City|Kingdom|Clash|Raid|Empire|War|Battle|Racing|Speed|Turbo|Drift|Moto|Soccer|Football|Basketball|Hockey|Tennis|Baseball|Boxing|Wrestling|UFC|NBA|NFL|FIFA|Madden'
Get-AppxPackage -ErrorAction SilentlyContinue | Where-Object { $_.Name -match $gamePat } |
    ForEach-Object { W ('GAME? ' + $_.Name + ' ' + $_.Version) }

W '--- CAPITALISM / INSTALLED GAME-LIKE ---'
$unins = @('HKLM:\Software\Microsoft\Windows\CurrentVersion\Uninstall\*',
           'HKLM:\Software\WOW6432Node\Microsoft\Windows\CurrentVersion\Uninstall\*',
           'HKCU:\Software\Microsoft\Windows\CurrentVersion\Uninstall\*')
Get-ItemProperty $unins -ErrorAction SilentlyContinue | Where-Object { $_.DisplayName -match 'Capitalism|Ubisoft|Nahimic|HONOR|荣耀|Game' } |
    Select-Object DisplayName, DisplayVersion, InstallLocation, UninstallString, QuietUninstallString |
    Format-List | Out-String -Width 240 | Write-Output

W '--- UBISOFT SERVICES / TASKS ---'
Get-CimInstance Win32_Service -ErrorAction SilentlyContinue | Where-Object { $_.Name -match 'ubi|uplay' -or $_.PathName -match 'Ubisoft|Uplay' } |
    Select-Object Name, DisplayName, State, StartMode, PathName | Format-List | Out-String -Width 240 | Write-Output
Get-ScheduledTask -ErrorAction SilentlyContinue | Where-Object { $_.TaskPath -match 'Ubisoft' -or $_.TaskName -match 'Ubisoft' } |
    Select-Object TaskName, TaskPath, State | Format-Table -AutoSize | Out-String | Write-Output
Get-Process -ErrorAction SilentlyContinue | Where-Object { $_.Name -match 'ubi|uplay' } |
    Select-Object Name, Id | Format-Table -AutoSize | Out-String | Write-Output

W '--- NAHIMIC ---'
Get-ScheduledTask -ErrorAction SilentlyContinue | Where-Object { $_.TaskName -match 'Nahimic' -or $_.TaskPath -match 'Nahimic' } |
    Select-Object TaskName, TaskPath, State | Format-Table -AutoSize | Out-String | Write-Output
Get-CimInstance Win32_Service -ErrorAction SilentlyContinue | Where-Object { $_.Name -match 'Nahimic|A-Volute|Nahimic' -or $_.PathName -match 'Nahimic|A-Volute' } |
    Select-Object Name, DisplayName, State, StartMode, PathName | Format-List | Out-String -Width 240 | Write-Output
Get-Process -ErrorAction SilentlyContinue | Where-Object { $_.Name -match 'Nahimic' } |
    Select-Object Name, Id, Path | Format-Table -AutoSize | Out-String | Write-Output

W '--- HONOR SERVICES / TASKS / RUN ---'
Get-CimInstance Win32_Service -ErrorAction SilentlyContinue | Where-Object { $_.Name -match 'HnPC|HunterCamp|MBAMain|QAX|Qax|GuardService|HONOR' -or $_.PathName -match 'HONOR|Honor|qianxin' } |
    Select-Object Name, DisplayName, State, StartMode, PathName | Format-List | Out-String -Width 240 | Write-Output
Get-ScheduledTask -ErrorAction SilentlyContinue | Where-Object { $_.TaskName -match 'HONOR|Honor|Hunter|Nahimic' -or $_.TaskPath -match 'HONOR|Honor' } |
    Select-Object TaskName, TaskPath, State | Format-Table -AutoSize | Out-String | Write-Output

W '--- HONOR PC MANAGER UNINSTALL ENTRY ---'
Get-ItemProperty $unins -ErrorAction SilentlyContinue | Where-Object { $_.DisplayName -match 'HONOR|荣耀|PCManager|电脑管家' } |
    ForEach-Object {
        W ('KEY=' + $_.PSChildName)
        W ('  DisplayName=' + $_.DisplayName)
        W ('  InstallLocation=' + $_.InstallLocation)
        W ('  UninstallString=' + $_.UninstallString)
        W ('  QuietUninstallString=' + $_.QuietUninstallString)
    }

W '--- DEFENDER STATE ---'
try {
    $mp = Get-MpComputerStatus -ErrorAction Stop
    W ('RealTimeProtectionEnabled=' + $mp.RealTimeProtectionEnabled + ' AntivirusEnabled=' + $mp.AntivirusEnabled + ' TamperProtectionSource=' + $mp.TamperProtectionSource)
    W ('AMServiceEnabled=' + $mp.AMServiceEnabled + ' BehaviorMonitorEnabled=' + $mp.BehaviorMonitorEnabled)
} catch { W ('Get-MpComputerStatus failed: ' + $_.Exception.Message) }
$dp = Get-ItemProperty 'HKLM:\SOFTWARE\Policies\Microsoft\Windows Defender' -ErrorAction SilentlyContinue
W ('Policy DisableAntiSpyware=' + $dp.DisableAntiSpyware)
Get-ItemProperty 'HKLM:\SOFTWARE\Microsoft\Windows Defender\Features' -ErrorAction SilentlyContinue |
    ForEach-Object { W ('TamperProtection=' + $_.TamperProtection) }

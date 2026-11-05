$ProgressPreference = 'SilentlyContinue'
$ErrorActionPreference = 'Continue'
function W([string]$t) { Write-Output $t }

W '--- CONSUMER-LIKE APPX ---'
$apps = Get-AppxPackage -ErrorAction SilentlyContinue
$pat = 'Xbox|Bing|Solitaire|Weather|News|Maps|People|Skype|Teams|Clipchamp|Feedback|GetHelp|GetStart|Tips|Cortana|MixedReality|OfficeHub|OneDrive|Zune|Groove|SoundRecorder|Camera|Photos|StickyNotes|Copilot|Recall|Phone|Gaming|Spotify|Netflix|Hulu|Duolingo|Amazon|Booking|Lipsum|Prime|TikTok|Instagram|Facebook|WhatsApp|LinkedIn|Twitter|Disney|Adobe|Dropbox|Eclipse|HP|McAfee|Norton|WinZip|Dolby|Bytedance|King|Play|Messaging|Journal|Whiteboard|ToDo|Mail|Calendar'
$apps | Where-Object { $_.Name -match $pat } | Select-Object Name, Version, Status |
    Sort-Object Name | Format-Table -AutoSize | Out-String -Width 160 | Write-Output

W '--- NON-STORE-SIGNED OR SIDELOADED ---'
$apps | Where-Object { $_.SignatureKind -ne 'Store' -and $_.SignatureKind -ne 'System' } |
    Select-Object Name, Version, SignatureKind, Status |
    Sort-Object Name | Format-Table -AutoSize | Out-String -Width 160 | Write-Output

W '--- PENDING REBOOT ---'
W ('CBS=' + (Test-Path 'HKLM:\SOFTWARE\Microsoft\Windows\CurrentVersion\Component Based Servicing\RebootPending'))
W ('WU=' + (Test-Path 'HKLM:\SOFTWARE\Microsoft\Windows\CurrentVersion\WindowsUpdate\Auto Update\RebootRequired'))
W ('PendingFileRename=' + [bool](Get-ItemProperty 'HKLM:\SYSTEM\CurrentControlSet\Control\Session Manager' -Name PendingFileRenameOperations -ErrorAction SilentlyContinue))

W '--- RECALL FEATURE QUERY (read-only via registry) ---'
$f = Get-ItemProperty 'HKLM:\SOFTWARE\Microsoft\Windows\CurrentVersion\Component Based Servicing\Packages\*Recall*' -ErrorAction SilentlyContinue
W ('packages matching Recall: ' + @($f).Count)

W '--- MEMORY NOW ---'
Get-Process -ErrorAction SilentlyContinue | Sort-Object WorkingSet64 -Descending | Select-Object -First 8 |
    Select-Object Name, Id, @{n='WSMB';e={[math]::Round($_.WorkingSet64/1MB)}} | Format-Table -AutoSize | Out-String | Write-Output

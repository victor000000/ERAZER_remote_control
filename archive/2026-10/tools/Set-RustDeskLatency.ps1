# Switches RustDesk away from software AV1 to hardware H.264 and ensures
# the hardware codec path is enabled. Run elevated (options are stored for
# the installed service).
$rd = 'C:\Program Files\RustDesk\rustdesk.exe'
if (-not (Test-Path $rd)) { throw "RustDesk not found at $rd" }

& $rd --option av1-test N
Start-Sleep -Seconds 1
& $rd --option codec-preference h264
Start-Sleep -Seconds 1
& $rd --option enable-hwcodec Y
Start-Sleep -Seconds 2
'options applied'

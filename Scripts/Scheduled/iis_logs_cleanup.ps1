$FilePath = "D:\PS\iis_logs_cleanup.ps1"
$LogPath = "C:\inetpub\logs\LogFiles"
$RotationPeriodInDays = 90
New-Item $FilePath -Force
Set-Content $FilePath "forfiles /P ${LogPath} /S /M *.log /D -${RotationPeriodInDays} /C 'cmd /c del @path & echo @path deleted'"

$Task = "Powershell.exe -NoProfile -ExecutionPolicy Bypass -File ${FilePath}"
SCHTASKS /CREATE /TN "CleanUp Weekly at 1am IIS logs older than $RotationPeriodInDays days" /TR $Task /SC WEEKLY /ST 01:00 /RU "NT AUTHORITY\SYSTEM" /RL HIGHEST /F | Out-Host

$FilePath = "D:\PS\release_backup_cleanup.ps1"
$RotationPeriodInDays = 7
New-Item $FilePath -Force
Set-Content $FilePath "forfiles /P D:\azagent\F1\_work\1\s /S /M *.zip /D -${RotationPeriodInDays} /C 'cmd /c del @path & echo @path deleted'"
Add-Content $FilePath "forfiles /P D:\azagent\F1\_work\2\s /S /M *.zip /D -${RotationPeriodInDays} /C 'cmd /c del @path & echo @path deleted'"
Add-Content $FilePath "forfiles /P D:\azagent\F1\_work\3\s /S /M *.zip /D -${RotationPeriodInDays} /C 'cmd /c del @path & echo @path deleted'"
Add-Content $FilePath "forfiles /P D:\azagent\F1\_work\4\s /S /M *.zip /D -${RotationPeriodInDays} /C 'cmd /c del @path & echo @path deleted'"


$Task = "Powershell.exe -NoProfile -ExecutionPolicy Bypass -File ${FilePath}"
SCHTASKS /CREATE /TN "CleanUp company.projecting.mono release backup zips older than $RotationPeriodInDays days" /TR $Task /SC WEEKLY /ST 01:30 /RU "NT AUTHORITY\SYSTEM" /RL HIGHEST /F | Out-Host
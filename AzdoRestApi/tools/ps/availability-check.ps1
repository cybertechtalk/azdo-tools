param(
    [string]$Url = "http://netscalerinfo.company.dk/definitions/group/phx/definition/MONO-P/services",
    [string]$RecipientEmail = "d4f8f5fc.companyonline.dk@emea.teams.ms",
    [string]$SenderEmail = "$([System.Net.Dns]::GetHostName())@company.dk",
    [string]$SmtpServer = "securemail.company.dk",
    [string]$Leg = $null
) 

$responce = Invoke-WebRequest $Url
          
if ($responce.StatusCode -eq '200') {
    $content = $responce | ConvertFrom-Json
    if ($Leg) {
        $outOfService = $content | Where-Object { ($_.currentState -eq "OUT OF SERVICE") -and ($_.leg -eq $Leg) }
    }
    else {
        $outOfService = $content | Where-Object { $_.currentState -eq "OUT OF SERVICE" }
    }
    if ($outOfService.count -gt 0) {
        $outOfService | Format-Table | Out-Host
        Send-MailMessage -From $SenderEmail -To $RecipientEmail -Subject "Availability check $($Url)" -Body ($outOfService | ConvertTo-Html | Out-String) -BodyAsHtml -SmtpServer $SmtpServer
        Write-Host "##[warning]notification sent."
    }

    else {
        Write-Host "##[section]all services up and running"
    }
    exit 0
}
else {
    Write-Host "##[error]"$request.StatusCode
    exit 1
}
Function Invoke-RequestWithRetry {
    Param(
        [Parameter(Mandatory=$True)]
        [string]$Url,
        [int]$Retries = 1,
        [int]$SecondsDelay = 5
    )
    $retryCount = 0
    $completed = $false
    $response = $null

    while (-not $completed) {
        try {
            Write-Host "[INFO] Invoking $Url ..."
            $response = Invoke-WebRequest $Url
            if ($response.StatusCode -ne 200) {
                throw "##[error] Expecting reponse code 200, was: $($response.StatusCode)"
            }
            $completed = $true
        } catch {
            if ($retrycount -ge $Retries) {
                Write-Host "##[warning] Request to $Url failed the maximum number of $retryCount times."
                throw
            } else {
                Write-Host "##[warning] Request to $Url failed. Retrying in $SecondsDelay seconds."
                Start-Sleep $SecondsDelay
                $retrycount++
            }
        }
    }

    return $response
}

Function Get-PipelineRunLogs {
    param(
        [Parameter(Mandatory=$true)]
        [string] $AzureDevOpsPAT,
        [Parameter(Mandatory=$true)]
        [string] $OrganizationName,
        [Parameter(Mandatory=$true)]
        [string] $ProjectName,
        [Parameter(Mandatory=$true)]
        [string] $RunId,
        [Parameter(Mandatory=$false)]
        [string] $Status
    )    
 
    $header = @{Authorization=("Basic {0}" -f $AzureDevOpsPAT)};
    $urlTimeline = 'https://dev.azure.com/'+ $OrganizationName + '/' + $ProjectName + '/_apis/build/builds/'+ $RunId +'/timeline/?api-version=6.0';

    $timeline = Invoke-RestMethod -Uri $urlTimeline -Headers $header -Method Get

    if($Status -eq 'failed') {
        $logs = $timeline.records | Where-Object {($_.result -eq 'failed') -and ($_.errorCount -gt 0)} | Select-Object $_ -ExpandProperty log
    }
    elseif($Status -eq 'succeeded') {  
        $logs = ($timeline.records | Where-Object {($_.result -eq 'succeeded') -and ($_.errorCount -eq 0)} | Select-Object $_ -ExpandProperty log)
    }
    else { 
        $logs = ($timeline.records | Select-Object $_ -ExpandProperty log)
    }

    $messages = $logs | ForEach-Object { (Invoke-WebRequest -Uri $_.url -Headers $auth -Method GET).Content }
    $sb = [System.Text.StringBuilder]::new()
    foreach ($msg in $messages) {
        $logTemplate = [System.IO.File]::ReadAllText("./Pipelines/templates/notification/log.html")
        $listsb = [System.Text.StringBuilder]::new()
        $msg -split "`r`n" | ForEach-Object { [void]$listsb.Append("$_<br>") }
        if($Status -eq 'failed') {
            $logTemplate = $logTemplate.Replace('${Severity}', '#f60000')  
        } 
        else {
            $logTemplate = $logTemplate.Replace('${Severity}', '#eaeaea') 
        }
        $logTemplate = $logTemplate.Replace('${Message}', $listsb.ToString())
        [void]$sb.Append($logTemplate)
    }
    return $sb.ToString()
}
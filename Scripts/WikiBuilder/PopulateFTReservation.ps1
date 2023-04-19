#global vars:
. "$PSScriptRoot\helper\helper-functions.ps1"
$headers = GetDefaultHeaders
$azdoURI = $env:azdoURI
$apiRootPath = [uri]::EscapeDataString("Feature Test Deployments")
$apiPath = [uri]::EscapeDataString("Feature Test Reservation")
$wikiUrl = "https://$azdoURI/_apis/wiki/wikis/projecting.wiki/pages?path=/${apiRootPath}/${apiPath}&includeContent=True&api-version=5.0"

function CreateMarkDownTable() {
    [CmdletBinding()]
    param (
        [Parameter()]
        [Hashtable]$headers,
        [PSCustomObject]$customList,
        [string]$wikiUrl
    )

    $mdContent += "####last update: $((Get-Date).ToString())`n"
    $mdContent += "| FT Leg | Build | From | To | Author | Created |`n"
    $mdContent += "| --- | --- | --- | --- | --- | --- |`n"

    foreach ($i in $customList) {
        $mdContent += "| $($i.PartitionKey) | $($i.RowKey) | $(([datetime]($i.From)).ToString('yyyy-MM-dd HH:mm:ss')) | $(([datetime]($i.To)).ToString('yyyy-MM-dd HH:mm:ss')) | $($i.Author) | $(([datetime]($i.TimeStamp)).ToString('yyyy-MM-dd HH:mm:ss')) | `n"
    }
    
    $body = @{ content = $mdContent }
    $headers = GetETag -headers $headers -wikiUrl $wikiUrl
    $r = Invoke-RestMethod -Uri $wikiUrl -Method Put -Headers $headers -Body ($body | ConvertTo-Json)
    $r
    Write-Host "##[section]Feature test reservation: $($r.remoteUrl)"
}
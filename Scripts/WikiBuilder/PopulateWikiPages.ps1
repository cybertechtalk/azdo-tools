<#
  .SYNOPSIS
  script creates WIKI pages.

  .DESCRIPTION
  The PopulateWikiPages.ps1 script creates WIKI pages with WorkItems - displayed as table in MarkDown.
  Wiki page: https://dev.azure.com/company-prod/projecting/_wiki/wikis/projecting.wiki/593/API-Change-log

  .INPUTS
  None. You cannot pipe objects to PopulateWikiPages.ps1.

  .OUTPUTS
  None. PopulateWikiPages.ps1 does not generate any output.
#>


$query = "
Select [System.Id] From WorkItems Where [System.State] IN ('Completed','Resolved','Done', 'Closed') AND [System.WorkItemType] IN ('Bug', 'Product Backlog Item')
AND [System.TeamProject] = 'projecting' AND [System.IterationPath] UNDER 'projecting\company_project' AND [System.Tags] CONTAINS 'ApiRelated'
"

# source helper functions:
. "$PSScriptRoot\helper\helper-functions.ps1"

function GetReleaseMonth() {
    Param(
        [switch]$Current,
        [switch]$Future
    )

    $monthNum = (Get-Date).Month
    if ($monthNum -eq 12) { $monthNum = 0 }
    $monthsMap = @{
        0 = @('DEC', 'December')
        1  = @('JAN', 'January')
        2  = @('FEB', 'February')
        3  = @('MAR', 'March')
        4  = @('APR', 'April')
        5  = @('MAY', 'May')
        6  = @('JUN', 'June')
        7  = @('JUL', 'July')
        8  = @('AUG', 'August')
        9  = @('SEP', 'September')
        10 = @('OCT', 'October')
        11 = @('NOV', 'November')
        12 = @('DEC', 'December')
    }

    if($Current) { 
        return @{
            abbreviation = $monthsMap[$monthNum][0]
            fullname     = $monthsMap[$monthNum][1]
        }
    }
    if($Future) {
        return @{
            abbreviation = $monthsMap[($monthNum + 1)][0]
            fullname     = $monthsMap[($monthNum + 1)][1]
        }
    }
}

function GetReleaseYear() {
    $now = Get-Date
    if($now.Month -eq 12) {
        return ($now.Year + 1)
    }
    return $now.Year
}

function CreateMarkdownTable {
    param (
        [PSCustomObject[]]$items,
        [string]$apiUri,
        [hashtable]$headers
    )
    $mdContent = ''
    foreach ($team in @('Day Shift', 'Night Shift')) {
        $teamItems = $items | ? { $_.Team -eq $team }
        $mdContent += "#$team`:`n"
        $mdContent += "| ID | Created | Updated |  What has been changed | Tags | Team | Release |`n"
        $mdContent += "| --- | --- | --- | --- | --- | --- | --- |`n"
        foreach ($item in $teamItems) {
            $mdContent += "| #$($item.ID) | $($item.CreatedDate) | $($item.ChangedDate) | $($item.ChangedInfo) | $($item.Tags) | $($item.Team) | $($item.Release) | $($item.Url) |`n" 
        }
        $mdContent += "&nbsp;`n&nbsp;`n"
    }

    $body = @{ content = $mdContent }
    Invoke-RestMethod -Uri $apiUri -Headers $headers -Method Put -Body ($body | ConvertTo-Json) -Verbose
}


$headers = GetDefaultHeaders
$releaseMonthCurrent = GetReleaseMonth -Current
$releaseMonthFuture = GetReleaseMonth -Future
$apiPath = [uri]::EscapeDataString("Release changelog - API")

foreach($month in @($releaseMonthCurrent, $releaseMonthFuture)) {
    if($month.fullname -eq 'December' -and $month -eq $releaseMonthCurrent) {
        $releaseYear = (GetReleaseYear) - 1
    }
    else {
        $releaseYear = GetReleaseYear
    }
    $headers = GetDefaultHeaders
    $itemsCustomArr = GetWorkitemsList -query $query
    # $itemsCustomArr | ft
    $sprints = $itemsCustomArr.IterationPath | select -Unique
    $releaseEncoded = [uri]::EscapeDataString("$($month.fullname) $releaseYear")
    # create parent Month page:
    $apiUri = "https://dev.azure.com/company-prod/projecting/_apis/wiki/wikis/projecting.wiki/pages?path=/${apiPath}/${releaseEncoded}&includeContent=True&api-version=5.0"
    try {
        $null = Invoke-RestMethod -Uri $apiUri -Headers $headers -Method Get
    }
    catch {
        if ($_.Exception.Response.StatusCode.value__ -eq 404 ) {
            Invoke-RestMethod -Uri $apiUri -Headers $headers -Method Put -Verbose
        }
    }

    # create/update sprint sub-pages:
    foreach ($sprint in $sprints) {
        $headers = GetDefaultHeaders
        $doesExist = $false
        $sprintEncoded = [uri]::EscapeDataString("Sprint $sprint")
        $items = $itemsCustomArr | ? { $_.IterationPath -eq $sprint }
        $apiUri = "https://dev.azure.com/company-prod/projecting/_apis/wiki/wikis/projecting.wiki/pages?path=/${apiPath}/${releaseEncoded}/${sprintEncoded}&includeContent=True&api-version=5.0"
        try {
            $r = Invoke-WebRequest -Uri $apiUri -Headers $headers -Method Get
            $doesExist = $true
        }
        catch {
            if ($_.Exception.Response.StatusCode.value__ -eq 404 ) {
                CreateMarkdownTable -items $items -apiUri $apiUri -headers $headers
            }
        }
        if ($doesExist) {  
            $headers.Add("If-Match", $r.Headers.ETag)
            CreateMarkdownTable -items $items -apiUri $apiUri -headers $headers
        }
    }
}
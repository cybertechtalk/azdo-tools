function EnrichWithComments() {
    [CmdletBinding()]
    param (
        [Parameter()]
        [PSCustomObject]$customList
    )

    $body = @{
        ids = $customList.Commit
    }

    $commitDetailsApi = "https://$azdoURI/_apis/git/repositories/$companyRepoId/commitsbatch?api-version=6.0&`$top=1000"
    $commitDetails = Invoke-RestMethod -Uri $commitDetailsApi -Method Post -Body ($body | ConvertTo-Json) -Headers $headers

    foreach ($i in $customList) {
        foreach ($commit in $commitDetails.value) {
            if ($commit.commitId -eq $i.Commit) {
                $i | Add-Member -MemberType NoteProperty -Name "Comment" -Value $commit.comment
                break
            }
        }
    }

    return $customList
}

function EnrichWithDeployLogs() {
    [CmdletBinding()]
    param (
        [Parameter()]
        [PSCustomObject]$customList
    )

    foreach ($i in $customList) {
        $timelineLogs = Invoke-RestMethod -Uri $i.TimeLine -Headers $headers -Method Get
        $filteredLogs = $timelineLogs.records | ? { $_.name -match 'Deploy to ' -and $_.result -eq 'succeeded' }
        if ($filteredLogs) {
            $ftLeg = ($filteredLogs.identifier | Select-String '[0-9]+').Matches.Value
        }
        else {
            $ftLeg = ''
        }
        $i | Add-Member -MemberType NoteProperty -Name "ftLegNumber" -Value $ftLeg
    }

    return $customList
}

function CreateMarkDownTable() {
    [CmdletBinding()]
    param (
        [Parameter()]
        [Hashtable]$headers,
        [PSCustomObject]$customList,
        [string]$wikiUrl
    )

    $mdContent += "####last update: $((Get-Date).ToString())`n"
    $mdContent += "Pipeline: [company.projecting.Mono - Featuretest YML](https://$azdoURI/_build?definitionId=518)`n"
    $mdContent += "| Release ID | FT Leg | Result | Branch | PBI | company Environment | Deployment Time |`n"
    $mdContent += "| --- | --- | --- | --- | --- | --- | --- |`n"
    foreach ($i in $customList) {
        $buildLink = "https://dev.azure.com/company-prod/58d9e17b-48bd-4f1c-90b4-f88c45e380d3/_build/results?buildId=$($i.BuildId)"
        if ($i.SourceBranch -match '[0-9]{5}') {
            $pbi = ($i.sourceBranch | Select-String '[0-9]{5}').Matches.Value
        }
        else { $pbi = $null }
        $pbiLink = "https://$azdoURI/_workitems/edit/$pbi"
        $mdContent += "| $($i.ReleaseName) | $($i.ftLegNumber) | $($i.Result) | $($i.SourceBranch) | [$pbi]($pbiLink) | $($i.companyEnvironment) | $($i.DeployTime) | `n"
    }
    
    $body = @{ content = $mdContent }
    $r = Invoke-RestMethod -Uri $wikiUrl -Method Put -Headers $headers -Body ($body | ConvertTo-Json)
    $r
    Write-Host "##[section]FT Deployments URL: $($r.remoteUrl)"
}


#global vars:
. "$PSScriptRoot\helper\helper-functions.ps1"
$headers = GetDefaultHeaders
$companyRepoId = $env:companyRepoId
$FTpipelineID = $env:FTpipelineID
$azdoURI = $env:azdoURI
$apiPath = [uri]::EscapeDataString("Latest Successful Deployments")
$apiRootPath = [uri]::EscapeDataString("Feature Test Deployments")
$wikiUrl = "https://$azdoURI/_apis/wiki/wikis/projecting.wiki/pages?path=/${apiRootPath}/${apiPath}&includeContent=True&api-version=5.0"


function main() {
    $customList = GetLatestPipelineRunsInfo -runsNum 25 -pipelineID $FTpipelineID
    # $enrichedWithComments = EnrichWithComments -customList $customList
    $enrichedWithLogs = EnrichWithDeployLogs -customList ($customList | ? {$_.TimeLine -match 'https'})
    $filteredCustomList = @()
    foreach ($i in $enrichedWithLogs) {
        if ($i.ftLegNumber -in $filteredCustomList.ftLegNumber) {
            Continue
        }
        else {
            $filteredCustomList += $i
        }
    }

    $filteredCustomList = $filteredCustomList | select -First 20

    # create WIKI page:
    try {
        $r = Invoke-WebRequest -Uri $wikiUrl -Headers $headers -Method Get -Verbose
        $exist = $true
    }
    catch {
        if ($_.Exception.Response.StatusCode.value__ -eq 404 ) {
            Invoke-RestMethod -Uri $wikiUrl -Headers $headers -Method Put -Verbose
        }
    }
    finally {
        if ($exist) { $eTag = $r.Headers.ETag }
        else {
            $r = Invoke-WebRequest -Uri $wikiUrl -Headers $headers -Method Get -UseBasicParsing -Verbose
            $eTag = $r.Headers.ETag
        }
        $headers = @{
            "Authorization" = "Basic $env:AZDO_PAT_B64"
            "Content-Type"  = "application/json"
            "If-Match"      = $eTag
        }
        CreateMarkDownTable -headers $headers -customList $filteredCustomList -wikiUrl $wikiUrl -Verbose
    }
}

main
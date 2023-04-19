function GetCommitDetailsFromTag() {
    [CmdletBinding()]
    Param(
        [string]$commitHash,
        [string]$commitTag
    )
    $commitApi = "https://$azdoUrl/_apis/git/repositories/$companyRepoId/commits/$commitHash`?api-version=6.0"
    $commitDetails = Invoke-RestMethod -Uri $commitApi -Method Get -Headers $headers
    return [PSCustomObject]@{
        details = $commitDetails
        tag     = $commitTag.Replace('refs/tags/', '')
        hash    = $commitHash
    }
}

function GetWorkItemsSinceTagCreation() {
    [CmdletBinding()]
    Param(
        [string]$cutOffFromDate,
        [string]$cutOffToDate = "",
        [string]$branch,
        [string]$fromTag,
        [string]$toTag
    )
    $body = @{
        itemVersion      = @{
            versionType = 'branch'
            version     = $branch
        }
        includeWorkItems = $true
        fromDate         = $cutOffFromDate # UTC ISO 8601 format
        toDate           = $cutOffToDate # toDate: value (upper bound aka the newest commit's date)
    }

    # PRs and corresponding WorkItems:
    $uri = "https://$azdoUrl/_apis/git/repositories/$companyRepoId/commitsbatch?api-version=6.0&`$top=2000"
    $response = Invoke-RestMethod $uri -Method 'POST' -Headers $headers -Body ($body | ConvertTo-Json) -Verbose
    $WorkItemsArr = @()
    $i = 0
    foreach ($r in $response.value) {
        $WorkItemsArr += [PSCustomObject]@{
            Nr          = ++$i
            Comment     = $r.comment
            WorkItems   = $r.workItems.id
            PullRequest = (($r.comment | Select-String 'Merged PR [0-9]{5}').Matches.Value -split ' ')[2]
            FromTag     = $fromTag
            ToTag       = $toTag
        }
    }

    return $WorkItemsArr
}

function CreateWikiPages() {
    [CmdletBinding()]
    param (
        [string]$monthName,
        [int]$yearNum,
        [object[]]$workItems,
        [switch]$postCombinedItems,
        [string]$fromTag,
        [string]$toTag
    )
    $headers = GetDefaultHeaders
    $rcName = $toTag
    $yrMonth = [uri]::EscapeDataString("$monthName $yearNum")

    $wikiUrlRel = "https://$azdoUrl/_apis/wiki/wikis/projecting.wiki/pages?path=/${apiPath}&includeContent=True&api-version=6.0"
    try { Invoke-RestMethod -Uri $wikiUrlRel -Method Put -Headers $headers -UseBasicParsing -Verbose } catch {}
    if($postCombinedItems) {
        $wikiUrl = "https://$azdoUrl/_apis/wiki/wikis/projecting.wiki/pages?path=/${apiPath}/${yrMonth}&includeContent=True&api-version=6.0"
        try { Invoke-RestMethod -Uri $wikiUrl -Method Put -Headers $headers -UseBasicParsing -Verbose } catch {}
    }
    else {
        $wikiUrlmonth = "https://$azdoUrl/_apis/wiki/wikis/projecting.wiki/pages?path=/${apiPath}/${yrMonth}&includeContent=True&api-version=6.0"
        $wikiUrl = "https://$azdoUrl/_apis/wiki/wikis/projecting.wiki/pages?path=/${apiPath}/${yrMonth}/${rcName}&includeContent=True&api-version=6.0"
        try { Invoke-RestMethod -Uri $wikiUrlmonth -Method Put -Headers $headers -UseBasicParsing -Verbose } catch {}
        try { Invoke-RestMethod -Uri $wikiUrl -Method Put -Headers $headers -UseBasicParsing -Verbose } catch {}
    }

    if($postCombinedItems) {
        $mdContent = "#Combined workitems for release - $monthName $yearNum`:`n"
        $mdContent += "&nbsp;`n"
    }
    else {
        $mdContent = "#Release candidate workitems:`n"
        $mdContent += "###all workitems between tags: `"$fromTag`" and `"$toTag`"`n"
    }
    $mdContent += "| WorkItem | Type | State | Title | Created | Link |`n"
    $mdContent += "| --- | --- | --- | --- | --- | --- |`n"
    foreach ($i in $workItems) {
        $wi = $i.'System.Id'
        $wiType = $i.'System.WorkItemType'
        $wiTitle = $i.'System.Title' -replace '#', ''
        [datetime]$wiCreated = $i.'System.CreatedDate'
        # [datetime]$wiModified = $i.'System.ChangedDate'
        $wiState = $i.'System.State'
        $wiLink = "https://$azdoUrl/_workitems/edit/$wi"
        # $mdContent += "| [$workitem](https://$azdoUrl" + "/_workitems/edit/" + $($i.WorkItems) + ")" + " | $($i.Comment) |`n"
        $mdContent += "| $wi | $wiType | $wiState | #$wi | $($wiCreated.ToString("dd/MM/yyyy HH:mm:ss")) | $wiLink |`n"
    }
    $body = @{ content = $mdContent }

    $isCreated = $true
    try{
        $r = Invoke-WebRequest -Uri $wikiUrl -Headers $headers -UseBasicParsing -Method Get -Verbose
    }
    catch {
        $isCreated = $false
    }
    if($isCreated) {
        $headers = GetDefaultHeaders
        $headers.Add("If-Match", $r.Headers.ETag)
        Invoke-RestMethod -Uri $wikiUrl -Method Put -Headers $headers -Body ($body | ConvertTo-Json -Compress) -Verbose
    }
    else {
        $headers = GetDefaultHeaders
        Invoke-RestMethod -Uri $wikiUrl -Method Put -Headers $headers -Body ($body | ConvertTo-Json -Compress) -Verbose
    }
}

function PostBuildInfoOnWiki() {
    param (
        [string]$monthName,
        [int]$yearNum,
        [int]$pipelineId
    )
    $pipelineRuns = GetLatestPipelineRunsInfo -runsNum 15 -pipelineID $pipelineId
    $pipelineRuns
    $releaseBranchPattern = $monthName.ToLower() + "-" + $yearNum
    $runsInfo = $pipelineRuns | ? { $_.ReleaseBranch -match $releaseBranchPattern }
    $headers = GetDefaultHeaders
    foreach($run in $runsInfo) {
        $r = Invoke-RestMethod -Uri $run.TimeLine -Headers $headers -Method Get
        $stage = $r.records | ? {$_.name -match 'Deploy to' -and $_.result -eq 'succeeded' -and $_.state -eq 'completed'}
        $stageName = $stage.name.replace('Deploy to ','') -join ' '
        $run | Add-Member -MemberType NoteProperty -Name DeployedToStage -Value $stageName
    }
    # get wiki page content and update:
    $yrMonth = [uri]::EscapeDataString("$monthName $yearNum")
    $wikiUrl = "https://$azdoUrl/_apis/wiki/wikis/projecting.wiki/pages?path=/${apiPath}/${yrMonth}&includeContent=True&api-version=6.0"
    $r = Invoke-WebRequest -Uri $wikiUrl -Method Get -UseBasicParsing -Headers $headers
    if($r.content -notmatch 'builds included') {
        $newContent = "## builds included:`n"
        $newContent += "| Release | CI Build | Deployed To |`n"
        $newContent += "| --- | --- | --- |`n"
        foreach($run in $runsInfo) {
            $newContent += "| $($run.ReleaseName) | $($run.ArtifactDisplayname) | $($run.DeployedToStage) |`n"
        }
        $newContent += ($r | ConvertFrom-Json).Content
        $headers = GetDefaultHeaders
        $headers.Add("If-Match", $r.Headers.ETag)
        $body = @{ content=$newContent }
        Invoke-RestMethod -Uri $wikiUrl -Method Put -Headers $headers -Body ($body | ConvertTo-Json -Compress) -Verbose
    }
}

function PrepareAndPostItems() {
    param(
        [PSCustomObject[]]$timeFrameParts,
        [string]$monthName,
        [int]$yearNum,
        [switch]$checkCodeStopDate
    )

    $itemsCombined = @()
    foreach ($part in ($timeFrameParts | ? { $_.to -ne $null })) {
        $workItems = GetWorkItemsSinceTagCreation -cutOffFromDate $part.from -cutOffToDate $part.to -branch $branch -fromTag $part.fromTag -toTag $part.toTag
        $allItems = $workItems.WorkItems | select -Unique
        $enrichedWorkitems = GetWorkitemsList -skipWiqlQuery
        $enrichedWorkitems = $enrichedWorkitems.value.fields
        $enrichedWorkitemsUnique = $enrichedWorkitems | Sort-Object -Unique -Property { $_.'System.Id' }
        $itemsCombined += $enrichedWorkitemsUnique
        CreateWikiPages -monthName $monthName -yearNum $yearNum -workItems $enrichedWorkitemsUnique -fromTag $part.fromTag -toTag $part.toTag
    }
    # post combined:
    $uniqueItemsCombined = $itemsCombined | Sort-Object -Unique -Property { $_.'System.Id' }
    if ($checkCodeStopDate) {
        if (!(isAfterReleaseDate($releaseMonthAbbrv))){
            CreateWikiPages -monthName $monthName -yearNum $yearNum -workItems $uniqueItemsCombined -postCombinedItems
        }
    }
    else {
        CreateWikiPages -monthName $monthName -yearNum $yearNum -workItems $uniqueItemsCombined -postCombinedItems
    }
}

function GetAnnotatedTagsDetails() {
    Param(
        [string]$tagPattern
    )
    $monthTagsReq = Invoke-RestMethod -Uri "https://$azdoUrl/_apis/git/repositories/$companyRepoId/refs?filter=tags/$tagPattern&api-version=6.0" -Method Get -Headers $headers
    if ($monthTagsReq.count -gt 0) {
        $monthCustomArr = @()
        foreach ($i in $monthTagsReq.value) {
            $commitInfo = Invoke-RestMethod -Uri "https://$azdoUrl/_apis/git/repositories/$companyRepoId/annotatedtags/$($i.objectId)?api-version=6.0" -Method Get -Headers $headers
            $monthCustomArr += [PSCustomObject]@{
                CommitId = $commitInfo.taggedObject.objectId
                Name     = $commitInfo.name
                Date     = $commitInfo.taggedBy.date
            }
        }
        return $monthCustomArr
    }
    return $null
}

# main:
# source hepler functions:
. "$env:functionsDir\helper-functions.ps1"
# for debugging:
# . C:\Users\t7245\Desktop\repos\company-project-DevOps\Scripts\WikiBuilder\helper\helper-functions.ps1
# cd C:\Users\t7245\Desktop\repos\company-project
$pipelineId = $env:projectingMonoPipelineId
$branch = $env:branchName
$companyRepoId = $env:companyRepoId
$azdoUrl = $env:azdoUrl
$azdoURI = $env:azdoUrl
$monthNum = (Get-Date).Month
$yearNum = (Get-Date).Year
[datetime]$currentMonth = "$monthNum-01-$yearNum"
$previousMonth = $currentMonth.AddMonths(-1)
$nextMonth = $currentMonth.AddMonths(1)
$previousMonth
$currentMonth
$nextMonth
$headers = GetDefaultHeaders
$monthName = (Get-Culture).DateTimeFormat.GetMonthName($monthNum)
$releaseMonthAbbrv = ($monthName | GetMonthAbbreviated).ToLower()
$prevMonthName = (Get-Culture).DateTimeFormat.GetMonthName($previousMonth.Month)
$prevMonthAbbrv = ($prevMonthName | GetMonthAbbreviated).ToLower()
$apiPath = [uri]::EscapeDataString("Release changelog - API")

$prevMonthTagPattern = "$($previousMonth.Year)-$prevMonthAbbrv"
$currMonthTagPattern = "$yearNum-$releaseMonthAbbrv"
$prevMonthTags = GetAnnotatedTagsDetails($prevMonthTagPattern)
$currMonthTags = GetAnnotatedTagsDetails($currMonthTagPattern)

$prevMonthTags
$currMonthTags

if($prevMonthTags -ne $null -and $currMonthTags -ne $null) {

    $prevMonthTagsUnique = @()
    foreach($m in $prevMonthTags) {
        if ($m.CommitId -in $prevMonthTagsUnique.CommitId) { Continue }
        $prevMonthTagsUnique += $m
    }
    $currMonthTagsUnique = @()
    foreach ($m in $currMonthTags) {
        if ($m.CommitId -in $currMonthTagsUnique.CommitId) { Continue }
        $currMonthTagsUnique += $m
    }

    $timeFrameParts = @()

    for($i=$prevMonthTagsUnique.Count -1; $i -ge 0; $i--) {
        if([datetime]$prevMonthTagsUnique[$i].Date -gt [datetime]$currMonthTagsUnique[0].Date) {
            Continue
        }
        $timeFrameParts += [PSCustomObject]@{
            from    = $prevMonthTagsUnique[$i].Date
            fromTag = $prevMonthTagsUnique[$i].Name
            to      = $currMonthTagsUnique[0].Date
            toTag   = $currMonthTagsUnique[0].Name
        }
        break
    }

    for ($i = 0; $i -lt $currMonthTagsUnique.Count; $i++) {
        if($currMonthTagsUnique[$i+1] -eq $null) { $to, $toTag = $null }
        else {
            $to = $currMonthTagsUnique[$i + 1].Date
            $toTag = $currMonthTagsUnique[$i + 1].Name
        }
        $timeFrameParts += [PSCustomObject]@{
            from    = $currMonthTagsUnique[$i].Date
            fromTag = $currMonthTagsUnique[$i].Name
            to      = $to
            toTag   = $toTag
        }
    }

    # PrepareAndPostItems -timeFrameParts $timeFrameParts -monthName $monthName -yearNum $yearNum -checkCodeStopDate
    PrepareAndPostItems -timeFrameParts $timeFrameParts -monthName $monthName -yearNum $yearNum

    if(isAfterReleaseDate($releaseMonthAbbrv)) {
        PostBuildInfoOnWiki -monthName $monthName -yearNum $yearNum -pipelineId $pipelineId
    }

    ## check next release:
    $nextMonthName = (Get-Culture).DateTimeFormat.GetMonthName($nextMonth.Month)
    $nextMonthAbbrv = ($nextMonthName | GetMonthAbbreviated).ToLower()
    $yearNum = $nextMonth.Year
    $adoTagApi = "https://$azdoUrl/_apis/git/repositories/$companyRepoId/refs?filter=tags/$yearNum-$nextMonthAbbrv&api-version=6.0"
    $headers = GetDefaultHeaders
    $r = Invoke-RestMethod -Uri $adoTagApi -Method Get -Headers $headers
    if($r.count -eq 1) {
        $tagId = $r.value.objectId
        $adoTagDetailsApi = "https://$azdoUrl/_apis/git/repositories/$companyRepoId/annotatedtags/${tagId}?api-version=6.0"
        $tagDetailsResponse = Invoke-RestMethod -Uri $adoTagDetailsApi -Method Get -Headers $headers
        $nextReleaseCommitDetails = GetCommitDetailsFromTag -commitTag $r.value.name -commitHash $tagDetailsResponse.taggedObject.objectId
        $filteredCurrentTimeframeParts = ($timeFrameParts | ? { $_.to -ne $null } | Sort-Object -Descending to)[0]
        $futureReleasetimeFrameParts = @()
        $futureReleasetimeFrameParts += [PSCustomObject]@{
            from    = $filteredCurrentTimeframeParts.to
            fromTag = $filteredCurrentTimeframeParts.toTag
            to      = $nextReleaseCommitDetails.details.committer.date
            toTag   = $nextReleaseCommitDetails.tag
        }
        $futureReleasetimeFrameParts
        PrepareAndPostItems -timeFrameParts $futureReleasetimeFrameParts -monthName $nextMonthName -yearNum $yearNum
    }
}
Add-Type "
    using System.Net;
    using System.Security.Cryptography.X509Certificates;
    public class TrustAllCertsPolicy : ICertificatePolicy {
        public bool CheckValidationResult(
            ServicePoint srvPoint, X509Certificate certificate,
            WebRequest request, int certificateProblem) {
            return true;
        }
    }
"
[System.Net.ServicePointManager]::CertificatePolicy = New-Object TrustAllCertsPolicy
[Net.ServicePointManager]::SecurityProtocol = [Net.SecurityProtocolType]::Tls12 -bor [Net.SecurityProtocolType]::Tls11 -bor [Net.SecurityProtocolType]::Tls -bor [Net.SecurityProtocolType]::Ssl3
[Net.ServicePointManager]::SecurityProtocol = "Tls, Tls11, Tls12, Ssl3"

function CalculateReleaseMonth() {
    $now = Get-Date
    $year = $now.Year
    #Compare with Codestop day+1 (midnight)
    if ($now -le [datetime]"$year-01-22") {
        $month = 'february'
    }
    elseif ($now -le [datetime]"$year-02-19") {
        $month = 'march'
    }
    elseif ($now -le [datetime]"$year-03-26") {
        $month = 'april'
    } 
    elseif ($now -le [datetime]"$year-04-23") {
        $month = 'may'
    } 
    elseif ($now -le [datetime]"$year-05-28") {
        $month = 'june'
    } 
    elseif ($now -le [datetime]"$year-08-20") {
        $month = 'september'
    } 
    elseif ($now -le [datetime]"$year-09-24") {
        $month = 'october'
    } 
    elseif ($now -le [datetime]"$year-10-29") {
        $month = 'november'
    } 
    else {
        $month = 'january'
        $year = [int]$year + 1
    }
    $months = @(
        "january",
        "february",
        "march",
        "april",
        "may",
        "june",
        "august",
        "september",
        "october",
        "november"
    )
    $now = Get-Date
    $nextMonthyear = $now.Year
    $prevMonthyear = $now.Year
    # $month = $now.Month
    # $currentMonth = (Get-Culture).DateTimeFormat.GetMonthName($month).ToLower()
    $currentMonth = $month
    if ($currentMonth -eq 'december' -or $currentMonth -eq 'november') {
        $nextMonth = 'january'
        $nextMonthyear = [int]$nextMonthyear + 1
    }
    elseif ($currentMonth -eq 'june' -or $currentMonth -eq 'july') {
        $nextMonth = 'august'
    }
    else {
        $nextMonth = $months[($months.IndexOf($currentMonth) + 1)]
    }

    if ($currentMonth -eq 'august' -or $currentMonth -eq 'july') {
        $prevMonth = 'june'
    }
    elseif ($currentMonth -eq 'january') {
        $prevMonth = 'november'
        $prevMonthyear = [int]$prevMonthyear - 1
    }
    elseif ($currentMonth -eq 'december') {
        $prevMonth = 'november'
    }
    else {
        $prevMonth = $months[($months.IndexOf($currentMonth) - 1)]
    }
    return @{
        'current' = @{
            'year'  = $now.Year
            'month' = $currentMonth
        }
        'prev'    = @{
            'year'  = $prevMonthyear
            'month' = $prevMonth
        }
        'next'    = @{
            'year'  = $nextMonthyear
            'month' = $nextMonth
        }
    }
}

function isAfterReleaseDate([string]$currentMonthAbbreviated) {
    # release calendar eventname: 'project Backend API'
    $now = Get-Date
    $year = $now.Year
    switch ($currentMonthAbbreviated) {
        jan { if ($now -gt [datetime]"$year-01-17") { return $true } }
        feb { if ($now -gt [datetime]"$year-02-14") { return $true } }
        mar { if ($now -gt [datetime]"$year-03-21") { return $true } }
        apr { if ($now -gt [datetime]"$year-04-23") { return $true } }
        may { if ($now -gt [datetime]"$year-05-23") { return $true } }
        jun { if ($now -gt [datetime]"$year-06-20") { return $true } }
        sep { if ($now -gt [datetime]"$year-09-13") { return $true } }
        oct { if ($now -gt [datetime]"$year-10-18") { return $true } }
        nov { if ($now -gt [datetime]"$year-11-22") { return $true } }
        Default {}
    }
    return $false
}

function GetMonthAbbreviated() {
    [CmdletBinding()]
    Param(
        [Parameter(ValueFromPipeline)]
        [string]$month
    )
    return $month.Substring(0, [System.Math]::Min($month.Length, 3))
}

function GetDefaultHeaders() {
    $headers = New-Object "System.Collections.Generic.Dictionary[[String],[String]]"
    $headers.Add("Authorization", "Basic $env:AZDO_PAT_B64")
    $headers.Add("Content-Type", "application/json")
    return $headers
}

function GetWorkitemsList {
    [cmdletbinding()]
    param (
        [string]$query,
        [switch]$skipWiqlQueryAndFilter
    )

    if ($skipWiqlQueryAndFilter) {}
    else {
        $body = @{ query = $query } | ConvertTo-Json
        $response = Invoke-RestMethod 'https://dev.azure.com/company-prod/projecting/company_project/_apis/wit/wiql?api-version=6.0' -Method 'POST' -Headers $headers -Body $body -Verbose
        $allItems = $response.workItems.id
    }
    $counter = [pscustomobject] @{ Value = 0 }
    $batchSize = 200
    $batches = $allItems | Group-Object -Property { [math]::Floor($counter.Value++ / $batchSize) }

    $batchResults = @()
    foreach ($batch in $batches) {
        $body = @{
            ids    = $batch.Group;
            fields = @(
                "System.AreaPath",
                "System.TeamProject",
                "System.IterationPath",
                "System.WorkItemType",
                "System.State",
                "System.Reason",
                "System.CreatedDate",
                "System.ChangedDate",
                "System.ChangedBy",
                "System.Id",
                "System.Title",
                "System.Tags",
                "Microsoft.VSTS.Scheduling.RemainingWork",
                "System.BoardColumn",
                "Microsoft.VSTS.Common.ValueArea",
                "company.Team",
                "company.SD_request_type",
                "company.Acc_1_Changed",
                "company.Acc_2_Contries",
                "company.Acc_3_Portlets_features",
                "company.Acc_4_Test",
                "company.Acc_5_Changes",
                "company.Acc_6_Other"
            )
        }

        $batchResults += Invoke-RestMethod 'https://dev.azure.com/company-prod/_apis/wit/workitemsbatch?api-version=6.0' -Method 'POST' -Headers $headers -Body ($body | ConvertTo-Json) -Verbose
    }
    
    if($skipWiqlQueryAndFilter) { return $batchResults }
    else {
        # $filteredItems = $batchResults.value.fields | ? { $_.'System.IterationPath' -match (GetReleaseMonth -Abbreviation) }
        $filteredItems = $batchResults.value.fields | ? { $_.'System.IterationPath' -match "$($month.abbreviation)" }
        $itemsCustomArr = @()
        foreach ($item in $filteredItems) {
            $teamName = ($item.'System.AreaPath' -split '\\')[-1]
            $iterationPath = ($item.'System.IterationPath' -split '\\')[-1]
            $sprint, $release = $iterationPath -split '\('
            $itemsCustomArr += [PSCustomObject]@{
                IterationPath = $iterationPath
                ID            = $item.'System.Id'
                WorkItemType  = $item.'System.WorkItemType'
                State         = $item.'System.State'
                CreatedDate   = $item.'System.CreatedDate'
                ChangedDate   = $item.'System.ChangedDate'
                Title         = $item.'System.Title'
                Tags          = $item.'System.Tags'
                Team          = $teamName
                Sprint        = $sprint.Trim()
                Release       = $release.Replace(')', '').Trim()
                Url           = "https://dev.azure.com/company-prod/projecting/_workitems/edit/$($item.'System.Id')"
                ChangedInfo   = $item.'company.Acc_1_Changed'
            }
        }
        return $itemsCustomArr
    }
}


function GetLatestPipelineRunsInfo() {
    [CmdletBinding()]
    param (
        [Parameter()]
        [int]$runsNum,
        [int]$pipelineID
    )

    $allPipelineRuns = Invoke-RestMethod -Uri "https://$azdoURI/_apis/pipelines/$pipelineID/runs?api-version=6.0" -Method Get -Headers $headers
    $latestRuns = $allPipelineRuns.value | ? { $_.result -contains 'succeeded' } | select -First $runsNum

    $latestRunsDetails = @()
    foreach ($run in $latestRuns) {
        $latestRunsDetails += Invoke-RestMethod -Uri "https://$azdoURI/_apis/build/builds/$($run.id)?api-version=6.0" -Method Get -Headers $headers
    }

    for($i=0; $i -lt $latestRunsDetails.Count; $i++) {
        $consumedArtifact = invoke-WebRequest -Uri "https://$azdoURI/_build/results?buildId=$($latestRunsDetails[$i].id)&view=artifacts&pathAsName=false&type=consumedArtifacts" -Method Get -UseBasicParsing -Headers $headers
        $artifactId = (($consumedArtifact.Content | Select-String '"versionId":"[0-9]+"' -AllMatches).Matches.Value | Select-String '[0-9]+' -AllMatches).Matches.Value
        $latestRunsDetails[$i] | Add-Member -MemberType NoteProperty -Name 'consumedArtifact' -Value $artifactId
        try { $r = Invoke-RestMethod -Uri "https://$azdoURI/_apis/build/builds/$artifactId`?api-version=6.0" -Method Get -Headers $headers -ErrorAction SilentlyContinue } catch { $r -eq $null }
        if($r -ne $null) {
            if ($r.sourceBranch -match 'pull/[0-9]+/merge') {
                $buildBranchName = ($r.parameters | ConvertFrom-Json).'system.pullRequest.sourceBranch'
            }
            else {
                $buildBranchName = $r.sourceBranch
            }
            $latestRunsDetails[$i] | Add-Member -MemberType NoteProperty -Name 'buildBranchName' -Value $buildBranchName
            $latestRunsDetails[$i] | Add-Member -MemberType NoteProperty -Name 'artifactDisplayname' -Value $r.buildNumber
        }
    }
    # $latestRunsDetails | select buildNumber, status, sourceBranch | Format-Table
    $customList = @()
    foreach ($i in $latestRunsDetails) {
        $customList += [PSCustomObject]@{
            ReleaseName         = $i.buildNumber
            ReleaseBranch       = $i.sourceBranch -replace 'refs/heads/', ''
            Result              = $i.result
            SourceBranch        = $i.buildBranchName -replace 'refs/heads/', ''
            DeployTime          = [datetime]$i.queueTime
            Commit              = $i.sourceVersion
            BuildId             = $i.id
            ConsumedArtifact    = $i.consumedArtifact
            ArtifactDisplayname = $i.artifactDisplayname
            TimeLine            = $i._links.timeline.href
            companyEnvironment      = $i.templateParameters.companyEnvironments
        }
    }

    return $customList
}

function GetETag() {
    [CmdletBinding()]
    param (
        [Parameter()]
        [Hashtable]$headers,
        [string]$wikiUrl
    )

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
        @{
            "Authorization" = $headers.Authorization
            "Content-Type"  = $headers.'Content-Type'
            "If-Match"      = $eTag
        }
    }
}
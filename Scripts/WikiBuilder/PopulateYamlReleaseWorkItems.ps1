
function GetSucessfulYamlDeployments() {
    param (
        [int]$selectFirst = 20
    )

    $headers = GetDefaultHeaders
    # $env:ReleasePipelineId = 533
    $r = Invoke-RestMethod -Uri "https://$env:azdoUrl/_apis/pipelines/$env:ReleasePipelineId/runs?api-version=6.0" -Headers $headers -Method Get
    $succeeded = $r.value | ? { $_.result -eq 'succeeded' } | select -first $selectFirst
    $deploymentsDetails = @()
    foreach($i in $succeeded) {
        $timeline = Invoke-RestMethod -Uri "https://$env:azdoUrl/_apis/build/builds/$($i.id)/Timeline?api-version=6.0" -Headers $headers -Method Get
        $deployedStages = $timeline.records | ? { $_.type -eq 'Stage' -and $_.result -eq 'succeeded' -and $_.state -eq 'completed' }
        $deployedStagesName = ($deployedStages.name | Select-String -Pattern 'PHX\-[a-zA-Z]+').Matches.Value

        try {
            $runDetails = Invoke-RestMethod -Uri $i.url -Method Get -Headers $headers
        }
        catch {
            if ($_.Exception.Response.StatusCode.value__ -eq 500 ) {
                continue
            }
        }
        $branchName = $runDetails.resources.repositories.self.refName -replace 'refs/heads/',''

        $deploymentsDetails += [PSCustomObject]@{
            ReleaseLink    = $i._links.web.href
            ReleaseName    = $i.name
            BuildId        = $i.id
            DeployedStages = $deployedStagesName
            Branch         = $branchName
            PipelineName   = $runDetails.pipeline.name
        }
    }
    
    return $deploymentsDetails
}

function EnrichWithWorkitems() {
    param (
        [PSCustomObject]$deploymentsDetails
    )
    $headers = GetDefaultHeaders
    foreach($i in $deploymentsDetails) {
        $workitems = Invoke-RestMethod -Uri "https://$env:azdoUrl/_apis/build/builds/$($i.BuildId)/workitems?api-version=6.0" -Method Get -Headers $headers
        $allItems = $workitems.value.id
        $workitemsDetails = GetWorkitemsList -skipWiqlQueryAndFilter
        $i | Add-Member -MemberType NoteProperty -Name 'workitemsDetails' -Value $workitemsDetails.value
    }
    return $deploymentsDetails
}

function CreateWikiPages {
    param (
        [PSCustomObject]$deploymentsDetails
    )
    
    $rootPage = [uri]::EscapeDataString("Release changelog - API")
    # $subPageName = $deploymentsDetails.PipelineName | select -First 1
    # $subPage = [uri]::EscapeDataString("$subPageName - YML")
    $subPage = [uri]::EscapeDataString($env:WikiSubPageTitle)
    $headers = GetDefaultHeaders
    $uri = "https://$env:azdoUrl/_apis/wiki/wikis/projecting.wiki/pages?path=/${rootPage}/${subPage}&api-version=6.0"
    try { Invoke-RestMethod -Uri $uri -Headers $headers -Method Put -Verbose -ErrorAction SilentlyContinue }
    catch {}

    foreach($d in $deploymentsDetails) {
        foreach ($env in $d.DeployedStages) {
            if ($env -match 'PILOT') { $env = 'Pilot (PHX-P-PILOT)' }
            elseif ($env -match 'PHX-P') { $env = 'Production (PHX-P)' }
            elseif ($env -match 'PHX-S') { $env = 'Preprod (PHX-S)' }
            elseif ($env -match 'PHX-T') { $env = 'Integrationtest (PHX-T)' }
            elseif ($env -match 'PHX-F') { $env = 'Featuretest (PHX-F)' }
            $mdContent = ""
            $mdContent += "# Release related Workitems`n"
            $mdContent += "Release AzDO link: [***$($d.ReleaseName)***]($($d.ReleaseLink)) `n"
            $mdContent += "Pipeline: [***$($d.PipelineName)***](https://dev.azure.com/company-prod/projecting/_build?definitionId=$env:ReleasePipelineId)`n"
            $mdContent += "| Workitem | Type | Title | Created | Modified | branch | link |`n"
            $mdContent += " | --- | --- | --- | --- | --- | --- | --- |`n"
            foreach ($wi in $d.workItemsDetails) {
                $mdContent += "| $($wi.id) | $($wi.fields.'System.WorkItemType') | #$($wi.id) | $([datetime]$wi.fields.'System.CreatedDate') | $([datetime]$wi.fields.'System.ChangedDate') | $($d.Branch) | https://dev.azure.com/company-prod/projecting/_workitems/edit/$($wi.id) |`n"
            }
            $body = @{ content = $mdContent }
            $envPageEncoded = [uri]::EscapeDataString($env)
            $releaseNameEncoded = [uri]::EscapeDataString($d.ReleaseName)
            $contentUri = "https://$env:azdoUrl/_apis/wiki/wikis/projecting.wiki/pages?path=/${rootPage}/${subPage}/${envPageEncoded}/${releaseNameEncoded}&includeContent=True&api-version=6.0"
            $headers = GetDefaultHeaders
            $doesExist = $false
            try { Invoke-RestMethod -Uri "https://$env:azdoUrl/_apis/wiki/wikis/projecting.wiki/pages?path=/${rootPage}/${subPage}/${envPageEncoded}&includeContent=True&api-version=6.0" -Method Put -Headers $headers -Verbose -ErrorAction SilentlyContinue }
            catch {}
            try {
                $r = Invoke-WebRequest -Uri $contentUri -Headers $headers -Method Get -Verbose
                $doesExist = $true
            }
            catch {
                if ($_.Exception.Response.StatusCode.value__ -eq 404 ) {
                    $headers = GetDefaultHeaders
                    Invoke-RestMethod -Uri $contentUri -Headers $headers -Method Put -Body ($body | ConvertTo-Json) -Verbose
                }
            }
            if ($doesExist) {
                $headers = GetDefaultHeaders
                $headers.Add("If-Match", $r.Headers.ETag)
                Invoke-RestMethod -Uri $contentUri -Headers $headers -Method Put -Body ($body | ConvertTo-Json) -Verbose
            }
        }
    }
}

# source helper functions
. "$PSScriptRoot\helper\helper-functions.ps1"
$deploymentsDetails = GetSucessfulYamlDeployments
if($deploymentsDetails) {
    $deploymentsDetails = EnrichWithWorkitems -deploymentsDetails $deploymentsDetails
    CreateWikiPages -deploymentsDetails $deploymentsDetails
}

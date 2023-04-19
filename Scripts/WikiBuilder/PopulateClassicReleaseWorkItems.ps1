

# source helper functions:
. "$PSScriptRoot\helper\helper-functions.ps1"
$headers = GetDefaultHeaders

function GetSuccessfulDeployments() {
    $releases = Invoke-RestMethod "https://vsrm.$env:azdoUrl/_apis/release/releases?definitionId=$env:ReleasePipelineId&api-version=6.0" -Method 'GET' -Headers $headers -Verbose
    $releasesDetails = @()
    foreach ($rel in $releases.value) {
        $releasesDetails += Invoke-RestMethod -Uri $rel.url -Method Get -Headers $headers -Verbose
    }

    $environments = $releasesDetails.environments.name | select -Unique
    $deployed = @()
    foreach ($en in $environments) {
        foreach ($i in $releasesDetails) {
            foreach ($env in $i.environments) {
                if ($env.status -eq 'succeeded' -and $env.name -eq $en) {
                    $deployed += [PSCustomObject]@{
                        status      = $env.status
                        envName     = $env.name
                        id          = $env.id
                        releaseId   = $env.releaseId
                        releaseName = $i.name
                        createdOn   = $i.createdOn
                        alias       = $i.artifacts.alias
                        branchName  = $i.artifacts.definitionReference.branches.name
                    }
                }
            }
        }
    }

    return $deployed
}

function GetRelatedWorkItems {
    param (
        [PSCustomObject]$successfulDeployments
    )
    $enrichedItems = @()
    $envs = $successfulDeployments.envName | select -Unique
    foreach ($env in $envs) {
        $currentEnvDeployed = $successfulDeployments | ? { $_.envName -eq $env }
        
        for ($i = 0; $i -lt $currentEnvDeployed.Count - 1; $i++) {
            $currReleaseId = $currentEnvDeployed[$i].releaseId
            $prevReleaseId = $currentEnvDeployed[$i + 1].releaseId
            $releatedWorkitemsUrl = "https://vsrm.$env:azdoUrl/_apis/release/releases/$currReleaseId/workitems?baseReleaseId=$prevReleaseId&api-version=6.0"
            $relItems = Invoke-RestMethod -Uri $releatedWorkitemsUrl -Method Get -Headers $headers -Verbose
            $currentEnvDeployed[$i] | Add-Member -MemberType NoteProperty -Name "relatedWorkItems" -Value $relItems.value.id -Force
            $currentEnvDeployed[$i] | Add-Member -MemberType NoteProperty -Name "previousRelease" -Value  $currentEnvDeployed[$i + 1].releaseName -Force
            $enrichedItems += $currentEnvDeployed[$i]
        }
    }
    return $enrichedItems
}

function CreateWikiPages {
    param (
        [PSCustomObject]$enrichedDeployments
    )
    $rootPage = [uri]::EscapeDataString("Release changelog - API")
    # $subPage = [uri]::EscapeDataString("RM company projecting Mono")
    $subPage = [uri]::EscapeDataString($env:WikiSubPageTitle)
    $uri = "https://$env:azdoUrl/_apis/wiki/wikis/projecting.wiki/pages?path=/${rootPage}/${subPage}&api-version=6.0"
    try { Invoke-RestMethod -Uri $uri -Headers $headers -Method Put -Verbose -ErrorAction SilentlyContinue }
    catch {}

    $environments = $enrichedDeployments.envName | select -Unique
    foreach ($env in $environments) {
        switch ($env) {
            { $_ -ceq 'Prod' }            { $env = 'prod' }
            { $_ -ceq 'PreProd' }         { $env = 'preprod' }
            { $_ -ceq 'IntegrationTest' } { $env = 'Integrationtest' }
        }
        $headers = GetDefaultHeaders
        $envPageEncoded = [uri]::EscapeDataString($env)
        # $envPageUri = "https://$env:azdoUrl/_apis/wiki/wikis/projecting.wiki/pages?path=/${rootPage}/${subPage}/${envPageEncoded}&includeContent=True&api-version=6.0"
        $envPageUri = "https://$env:azdoUrl/_apis/wiki/wikis/projecting.wiki/pages?path=/${rootPage}/${subPage}/${envPageEncoded}&api-version=6.0"

        try { Invoke-RestMethod -Uri $envPageUri -Method Put -Headers $headers -Verbose -ErrorAction SilentlyContinue }
        catch {}

        $currentDeployments = $enrichedDeployments | ? { $_.envName -eq $env }
        foreach ($d in $currentDeployments) {
            $relId = $d.releaseId
            $relName = $d.releaseName
            $releaseWebUrl = "https://$env:azdoUrl/_releaseProgress?releaseId=$relId"
            $mdContent = ""
            $mdContent += "# Release related Workitems`n"
            $mdContent += "Release AzDO link: [***$relName***]($releaseWebUrl) `n"
            $mdContent += "## Showing changes compared to $($d.previousRelease) (Previous deployment)`n"
            $mdContent += "| Workitem | Type | Title | Created | Modified | branch | link |`n"
            $mdContent += " | --- | --- | --- | --- | --- | --- | --- |`n"
            foreach ($wi in $d.workItemsDetails) {
                # $mdContent += "| $($wi.id) | $($wi.fields.'System.WorkItemType') | $($wi.fields.'System.Title') | $($wi.fields.'System.CreatedDate') | $($wi.fields.'System.ChangedDate') | $($d.branchName) | https://dev.azure.com/company-prod/projecting/_workitems/edit/$($wi.id) |`n"
                $mdContent += "| $($wi.id) | $($wi.fields.'System.WorkItemType') | #$($wi.id) | $([datetime]$wi.fields.'System.CreatedDate') | $([datetime]$wi.fields.'System.ChangedDate') | $($d.branchName) | https://dev.azure.com/company-prod/projecting/_workitems/edit/$($wi.id) |`n"
            }
            $body = @{ content = $mdContent }
            $contentUri = "https://$env:azdoUrl/_apis/wiki/wikis/projecting.wiki/pages?path=/${rootPage}/${subPage}/${envPageEncoded}/$($d.releaseName)&includeContent=True&api-version=6.0"
            $headers = GetDefaultHeaders
            $doesExist = $false
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
            if($doesExist) {
                $headers = GetDefaultHeaders
                $headers.Add("If-Match", $r.Headers.ETag)
                Invoke-RestMethod -Uri $contentUri -Headers $headers -Method Put -Body ($body | ConvertTo-Json) -Verbose
            }
        }
    }
}

function GetRelatedWorkItemsDetails {
    param (
        [PSCustomObject]$enrichedDeployments
    )

    foreach ($i in $enrichedDeployments) {
        $allItems = $i.relatedWorkItems
        $workitemsDetails = GetWorkitemsList -skipWiqlQueryAndFilter
        $i | Add-Member -MemberType NoteProperty -Name "workItemsDetails" -Value $workitemsDetails.value -Force
    }
    return $enrichedDeployments
}

# main:
$started = Get-Date
$deployments = GetSuccessfulDeployments
$enrichedDeployments = GetRelatedWorkItems -successfulDeployments $deployments
$enrichedDeployments = $enrichedDeployments | ? { $_.relatedWorkItems -ne $null } | Sort-Object -Descending releaseName
$enrichedDeploymentsUniqueIds = @()
$enrichedDeploymentsUnique = @()
foreach($dep in $enrichedDeployments) {
    if($dep.id -notin $enrichedDeploymentsUniqueIds) {
        $enrichedDeploymentsUnique += $dep
        $enrichedDeploymentsUniqueIds += $dep.id
    }
}
$enrichedDeploymentsDetails = GetRelatedWorkItemsDetails -enrichedDeployments $enrichedDeploymentsUnique
CreateWikiPages -enrichedDeployments $enrichedDeploymentsDetails
$ts = New-TimeSpan -Start $started
Write-Host "elapsed time: $($ts.Hours)h:$($ts.Minutes)m:$($ts.Seconds)s" -ForegroundColor Green
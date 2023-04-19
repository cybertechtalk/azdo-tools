[CmdletBinding()]

param(
    [Parameter(Mandatory=$true)]
    [string] $AzureDevOpsPAT,
    [Parameter(Mandatory=$true)]
    [string] $OrganizationName,
    [Parameter(Mandatory=$true)]
    [string] $teamProjectName,
    [Parameter(Mandatory=$true)]
    [string] $repositoryName,
    [Parameter(Mandatory=$true)]
    [string] $fromBranch,
    [Parameter(Mandatory=$true)]
    [string] $toBranch
)


$ErrorActionPreference = 'Stop';
$header = @{Authorization=("Basic {0}" -f $AzureDevOpsPAT)};

# Get repository
$url = 'https://dev.azure.com/'+ $OrganizationName + '/' + $teamProjectName + '/_apis/git/repositories/' + $repositoryName
$repository = Invoke-RestMethod -Uri $Url -Method Get -ContentType application/json -Headers $header

$url = 'https://dev.azure.com/'+ $OrganizationName + '/' + $teamProjectName + '/_apis/git/repositories/' + $repository.id + '/pullrequests'

# Create a Pull Request
$pullRequest = @{
        "sourceRefName" = "refs/heads/$fromBranch"
        "targetRefName" = "refs/heads/$toBranch"
        "title" = "PR Automated - from $fromBranch to $toBranch"
        "description" = "Pull request from esb branch to release candidate branch"
    }

$pullRequestJson = ($pullRequest | ConvertTo-Json -Depth 10)

# REST call to create a Pull Request
$pullRequestResult = Invoke-RestMethod -Method POST -ContentType application/json -Headers $header -Body $pullRequestJson -Uri ($url + '?api-version=6.0');
$pullRequestId = $pullRequestResult.pullRequestId

Write-Host "##vso[task.setvariable variable=pullRequestId;]$pullRequestId"

# Set PR to auto-complete
$setAutoComplete = @{
    "autoCompleteSetBy" = @{
        "id" = $pullRequestResult.createdBy.id
    }
    "completionOptions" = @{       
        "mergeCommitMessage" = $pullRequestResult.title
        "deleteSourceBranch" = $True
        "bypassPolicy" = $False
        "mergeStrategy" = "squash"
    }
}

$setAutoCompleteJson = ($setAutoComplete | ConvertTo-Json -Depth 10)

# REST call to set auto-complete on Pull Request
$pullRequestUpdateUrl = ($url + '/' + $pullRequestId + '?api-version=6.0')

$setAutoCompleteResult = Invoke-RestMethod -Method PATCH -ContentType application/json -Headers $header -Body $setAutoCompleteJson -Uri $pullRequestUpdateUrl

Write-Output ConvertFrom-Json($setAutoCompleteResult)







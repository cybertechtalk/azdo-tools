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
    [string] $pullRequestId,
    [Parameter(Mandatory=$true)]
    [string] $reviewerId,
    [Parameter(Mandatory=$false)]
    [string] $reviewerForId=$null,
    [Parameter(Mandatory=$true)]
    [int] $vote
)


$ErrorActionPreference = 'Stop';
$header = @{Authorization=("Basic {0}" -f $AzureDevOpsPAT)};

# Get repository
$url = 'https://dev.azure.com/'+ $OrganizationName + '/' + $teamProjectName + '/_apis/git/repositories/' + $repositoryName
$repository = Invoke-RestMethod -Uri $Url -Method Get -ContentType application/json -Headers $header

# Getting reviewer list
$url = 'https://dev.azure.com/'+ $OrganizationName + '/' + $teamProjectName + '/_apis/git/repositories/' + $repository.id + '/pullrequests/' + $pullRequestId + '/reviewers/' + $reviewerId + '?api-version=6.0'

$reviewer = @{
    "vote" = $vote
    "id" = $reviewerId
    "votedFor" = @(if($reviewerForId) {@{ "id" = $reviewerForId }})
} 

# # Approve pull request
$body = ($reviewer | ConvertTo-Json -Depth 5);
$response = Invoke-WebRequest -Method Put -ContentType application/json -Uri $url -headers $header -body $body

Write-Output $response.Content | ConvertTo-Json


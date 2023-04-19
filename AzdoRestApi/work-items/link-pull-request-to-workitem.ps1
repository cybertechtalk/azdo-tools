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
    [Parameter(Mandatory=$false)]
    [string] $workItemId
)


$ErrorActionPreference = 'Stop';
$header = @{Authorization=("Basic {0}" -f $AzureDevOpsPAT)};

# Get repository
$url = 'https://dev.azure.com/'+ $OrganizationName + '/' + $teamProjectName + '/_apis/git/repositories/' + $repositoryName
$repository = Invoke-RestMethod -Uri $Url -Method Get -ContentType application/json -Headers $header

# Get work item
$url = 'https://dev.azure.com/'+ $OrganizationName + '/' + $teamProjectName + '/_apis/wit/workitems/' + $workItemId + '?api-version=6.0'

# Attach ArtifactLink
$request = @(
    @{
        "op" = "add"
        "path" = "/relations/-"
        "value" = @{
            "attributes" = @{
                "name" = "Pull Request"
            }
            "rel" = "ArtifactLink"
            "url" = "vstfs:///Git/PullRequestId/" + $teamProjectName + "/" + $repository.id + "/" + $pullRequestId
        }
    }
)
$requestJson = ($request | ConvertTo-Json -Depth 10)

$response = Invoke-RestMethod -Method PATCH -ContentType application/json-patch+json -Headers $header -Body $requestJson -Uri $url;

Write-Output ConvertFrom-Json($response)







Function Get-WorkItemsList
{
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
        [string] $pullRequestId
    )

    $ErrorActionPreference = 'Stop';
    $header = @{Authorization=("Basic {0}" -f $AzureDevOpsPAT)};

    # Get repository
    $url = 'https://dev.azure.com/'+ $OrganizationName + '/' + $teamProjectName + '/_apis/git/repositories/' + $repositoryName
    $repository = Invoke-RestMethod -Uri $Url -Method Get -ContentType application/json -Headers $header

    # Getting pr work items list
    $url = 'https://dev.azure.com/'+ $OrganizationName + '/' + $teamProjectName + '/_apis/git/repositories/' + $repository.id + '/pullrequests/' + $pullRequestId + '/workitems?api-version=6.0'

    $response = Invoke-WebRequest -Method Get -ContentType application/json -Uri $url -headers $header
    return $response;
}
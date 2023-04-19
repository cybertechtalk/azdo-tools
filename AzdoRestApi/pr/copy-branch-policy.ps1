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
$Url = 'https://dev.azure.com/'+ $OrganizationName + '/' + $teamProjectName + '/_apis/git/repositories/' + $repositoryName +'?api-version=6.0'
$repository = Invoke-RestMethod -Uri $Url -Method Get -ContentType application/json -Headers $header

$Url = 'https://dev.azure.com/'+ $OrganizationName + '/' + $teamProjectName + 
            '/_apis/git/policy/configurations?repositoryId=' + $repository.id + '&refName=refs/heads/' + $fromBranch + '&api-version=6.0-preview.1'

# Get policies
$policies = Invoke-RestMethod -Uri $Url -Method Get -ContentType application/json -Headers $header

$Url = 'https://dev.azure.com/'+ $OrganizationName + '/' + $teamProjectName + '/_apis/policy/configurations?api-version=6.0';


foreach($policy in $policies.value)
{
    if ($policy.type.id -eq '0517f88d-4ec5-4343-9d26-9930ebd53069') 
    {
        continue; # skipping GitRepositorySettingsPolicyName
    }

    if ($policy.type.id -eq '40e92b44-2fe1-4dd6-b3d8-74a9c21d0c6e') 
    {
        continue; # skipping 'Work item linking'
    }

    # remove properties from policy so it can be applied to target branch
    $props = $policy.PSObject.Properties
    $props.remove('createdBy');
    $props.remove('createdDate');
    $props.remove('revision');
    $props.remove('id');
    $props.remove('url');

    $policy._links.PSObject.Properties.Remove('self')

    # set target branch
    if (($null -ne $policy.settings.scope[0].refname))
    {
        $policy.settings.scope[0].refName = 'refs/heads/' + $toBranch;
    }
    if (($null -ne $policy.settings.searchBranches))
    {
        $policy.settings.searchBranches[0] = 'refs/heads/' + $toBranch;
    }  

    # create policy in target branch
    $body = $policy | ConvertTo-Json -Depth 10

    $policyCreateResponse = Invoke-RestMethod -Uri $Url -Method Post -Body $body -ContentType application/json -Headers $header
    
    Write-Output ConvertFrom-Json($policyCreateResponse)
}
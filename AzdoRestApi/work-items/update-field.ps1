[CmdletBinding()]

param(
    [Parameter(Mandatory=$true)]
    [string] $AzureDevOpsPAT,
    [Parameter(Mandatory=$true)]
    [string] $OrganizationName,
    [Parameter(Mandatory=$true)]
    [string] $teamProjectName,
    [Parameter(Mandatory=$true)]
    [string] $workItemId,
    [Parameter(Mandatory=$true)]
    [string] $fieldName,
    [Parameter(Mandatory=$true)]
    [string] $op,
    [Parameter(Mandatory=$false)]
    [string] $value
)


$ErrorActionPreference = 'Stop';
$header = @{Authorization=("Basic {0}" -f $AzureDevOpsPAT)};

# Get work item
$url = 'https://dev.azure.com/'+ $OrganizationName + '/' + $teamProjectName + '/_apis/wit/workitems/' + $workItemId + '?api-version=6.0'
$workItem = Invoke-RestMethod -Method GET -Headers $header -Uri $url

if ($op -eq "append") {
    $value = ($workItem.fields | Select -ExpandProperty $fieldName) + ", " + $value
    $op = "add"
}

# Update
$request = @(
    @{
        "op" = "test"
        "path" = "/rev"
        "value" = $workItem.rev
    },
    @{
        "op" = $op
        "path" = $path
        "value" = $value
    }
)
$requestJson = ($request | ConvertTo-Json -Depth 10)

$response = Invoke-RestMethod -Method PATCH -ContentType application/json-patch+json -Headers $header -Body $requestJson -Uri $url;

Write-Output $response





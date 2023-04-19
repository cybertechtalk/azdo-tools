[CmdletBinding()]

### Usage example
# [string] $AzureDevOpsPAT = <PAT>,
# [string] $OrganizationName = 'company-prod',
# [string] $ProjectName = 'projecting',
# [string] $PipelineId = 533 ex. RM company.projecting.Mono (https://dev.azure.com/company-prod/projecting/_build?definitionId=533),
# [string] $BranchName ~~ refs/heads/<branch-name>, default refs/heads/master
# [string[]] $StagesToSkip #stagesToSkip ~~ [ "Test", "Dev" ], default []

param(
    [Parameter(Mandatory=$true)]
    [string] $AzureDevOpsPAT,
    [Parameter(Mandatory=$true)]
    [string] $OrganizationName,
    [Parameter(Mandatory=$true)]
    [string] $ProjectName,
    [Parameter(Mandatory=$true)]
    [string] $PipelineId,
    [Parameter(Mandatory=$false)]
    [string] $BranchName,
    [Parameter(Mandatory=$false)]
    [string] $BuildId,
    [Parameter(Mandatory=$false)]
    [string] $Proxy,
    [Parameter(Mandatory=$false)]
    [string[]] $StagesToSkip,
    [Parameter(Mandatory=$false)]
    [string] $TemplateParameters
)    

Add-Type @"
    using System.Net;
    using System.Security.Cryptography.X509Certificates;
    public class TrustAllCertsPolicy : ICertificatePolicy {
        public bool CheckValidationResult(
            ServicePoint srvPoint, X509Certificate certificate,
            WebRequest request, int certificateProblem) {
            return true;
        }
    }
"@
[System.Net.ServicePointManager]::CertificatePolicy = New-Object TrustAllCertsPolicy
[System.Net.ServicePointManager]::SecurityProtocol = [System.Net.SecurityProtocolType]::Tls11 -bor [System.Net.SecurityProtocolType]::Tls12 -bor [System.Net.SecurityProtocolType]::Tls13;
    

$url = 'https://dev.azure.com/'+ $OrganizationName + '/' + $ProjectName + '/_apis/pipelines/' + $PipelineId + '/runs?api-version=6.0-preview.1';
$header = @{Authorization=("Basic {0}" -f $AzureDevOpsPAT)};

if([string]::IsNullOrWhiteSpace($BranchName))
{
   $BranchName = "refs/heads/master"
}

if([string]::IsNullOrWhiteSpace($StagesToSkip))
{
    $StagesToSkip = '[]'
}

if([string]::IsNullOrWhiteSpace($TemplateParameters))
{
    $TemplateParameters = '{}'
}

$buildAdd =""
if($BuildId -ne "latest")
{    $buildAdd = ',
        "pipelines": {
                "build": {
                    "version": "' + ${BuildId} + '"
                }
         }
    '
}

$body = '{
    "resources": {
        "repositories": {
            "self": {
                "refName": "' + ${BranchName} + '"
            }
        }' + ${buildAdd} + 
    '},
    "stagesToSkip":' + $StagesToSkip + ',
    "templateParameters":' + $templateParameters + '
}';

Write-Output $body

if ([string]::IsNullOrWhiteSpace($Proxy))
{
    $response = Invoke-RestMethod -Method POST -ContentType 'application/json' -Headers $header -Body $body -Uri $url;    
} 
else 
{
    $response = Invoke-RestMethod -Method POST -ContentType 'application/json' -Headers $header -Body $body -Uri $url -Proxy $Proxy; 
}

Write-Output $response.resources.pipelines
$webui = $response._links.web.href
Write-Host "`n`n"
Write-Host "##[section]pipeline web ui link: $webui`n`n"
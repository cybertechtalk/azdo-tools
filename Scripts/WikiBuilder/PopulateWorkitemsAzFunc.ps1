[CmdletBinding()]
param (
    [Parameter(Mandatory=$true)]
    [string]$fromDate,
    [Parameter(Mandatory=$true)]
    [string]$toDate,
    [Parameter(Mandatory=$true)]
    [string]$releaseBranch,
    [Parameter(Mandatory=$true)]
    [string]$pageName,
    [Parameter(Mandatory=$true)]
    [string]$func
)

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

. "$env:functionsDir\helper-functions.ps1"
$funcUri = $env:AzFuncUri
$funcCode = $env:FUNC_CODE
if ($func -eq 'companyadofunctionsapplx') {
    $funcUri = $env:AzFuncUriLx
    $funcCode = $env:FUNC_CODE_LX
}
$azdoUrl = $env:azdoUrl
$apiPath = [uri]::EscapeDataString("Release changelog - API")
$yrMonth = [uri]::EscapeDataString($pageName)
$wikiUrl = "https://$azdoUrl/_apis/wiki/wikis/projecting.wiki/pages?path=/${apiPath}/${yrMonth}&includeContent=True&api-version=6.0"
$AzFuncUrl = "${funcUri}GetWorkItemsFunction?from=${fromDate}&to=${toDate}&branch=${releaseBranch}&code=${funcCode}"
$respMarkdown = Invoke-RestMethod -Uri $AzFuncUrl -Method Get -UseBasicParsing -TimeoutSec 30
$respMarkdown

# check if markdown is not empty
if($respMarkdown -match '[0-9]') {
    $headers = GetDefaultHeaders
    $isCreated = $true
    try {
        $r = Invoke-WebRequest -Uri $wikiUrl -Headers $headers -Method Get -UseBasicParsing -Verbose
    }
    catch {
        if($_.Exception.Response.StatusCode.Value__ -eq 404) {
            $isCreated = $false
        }
    }
    finally {
        if($isCreated) {
            $headers.Add("If-Match", $r.Headers.ETag)
        }
        # update with markdown payload:
        $body = @{ content = $respMarkdown }
        Invoke-RestMethod -Uri $wikiUrl -Method Put -Headers $headers -Body ($body | ConvertTo-Json -Compress) -Verbose
    }
}
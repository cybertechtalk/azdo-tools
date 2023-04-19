[CmdletBinding()]

### Usage example
# [string] $AzureDevOpsPAT = <PAT>,
# [string] $OrganizationName = 'company-prod',
# [string] $ProjectName = 'projecting',
# [int] $IdleTim = 15, time elapsed till WI creation, the WI is ready to be audited in [min]
# [int] $Interval = 60, audit intervainl [min]

param(
    [Parameter(Mandatory=$true)]
    [string] $AzureDevOpsPAT,
    [Parameter(Mandatory=$true)]
    [string] $OrganizationName,
    [Parameter(Mandatory=$true)]
    [string] $ProjectName,
    [Parameter(Mandatory=$false)]
    [string] $AreaPath,
    [Parameter(Mandatory=$false)]
    [int] $IdleTime = 15,
    [Parameter(Mandatory=$false)]
    [int] $Interval = 60
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

$header = @{
    "Authorization" = "Basic $AzureDevOpsPAT"
    "Content-Type"  = "application/json"
}

# Get work items by WIQL
$url = "https://dev.azure.com/$OrganizationName/$ProjectName/_apis/wit/wiql?timePrecision=true&api-version=7.1-preview.2"
$body = @{
    "query" = "
        SELECT * FROM WorkItems WHERE ([System.WorkItemType] = 'Product Backlog Item' OR [System.WorkItemType] = 'Bug')
            $(If ($AreaPath) {"AND [System.AreaPath] IN ('"+($AreaPath.Split(',') -join "','")+"')"})
            AND [System.CreatedDate] <= '$(([System.DateTime]::UtcNow).AddMinutes(-$IdleTime))'
            AND [System.CreatedDate] >= '$(([System.DateTime]::UtcNow).AddMinutes(-$IdleTime-$Interval))'
    "
}

Write-Output $body.query
$pbis = Invoke-RestMethod -Method POST -ContentType application/json -Headers $header -Body ($body | ConvertTo-Json) -Uri $url;
Write-Output ConvertFrom-Json($pbis)

foreach ($pbi in $pbis.WorkItems) {
    $item = Invoke-RestMethod -Uri ('https://dev.azure.com/'+$OrganizationName+'/'+$ProjectName+'/_apis/wit/workitems/'+ $pbi.id +'?$expand=relations&api-version=7.1-preview.3') -Headers $header -Method Get 
        
    if (($item.relations | Where-Object rel -eq 'System.LinkTypes.Hierarchy-Reverse' | Measure-Object).Count -eq 0) {
        $emailTo = $item.fields.'System.CreatedBy'.uniqueName
        $title ='[Promark Sentinel] Parent missing in Work Item #' + $item.id
        $link = $item._links.html.href

        $content = [System.IO.File]::ReadAllText("./Pipelines/templates/promarksentinel/main.html")
        $content = $content.Replace('${Title}', $title)
        $content = $content.Replace('${Project}', "$OrganizationName/$ProjectName")
        $content = $content.Replace('${AreaPath}', $item.fields.'System.AreaPath')
        $content = $content.Replace('${WorkItemType}', $item.fields.'System.WorkItemType')
        $content = $content.Replace('${id}', $item.id)
        $content = $content.Replace('${WITitle}', $item.fields.'System.Title')
        $content = $content.Replace('${Author}', $emailTo)
        $content = $content.Replace('${Created}', ([DateTime]$item.fields.'System.CreatedDate').ToString("dd.MM.yyyy HH:mm:ss"))
        $content = $content.Replace('${Link}', "$link")
        $content = $content.Replace('${EmailMessage}', "Promark sentinel: please link Work Item to a parent Feature or Epic")

        Send-MailMessage -From "Azure DevOps <azuredevops@company.dk>" -To $emailTo -Subject $title -Body $content -BodyAsHtml -SmtpServer 'securemail.company.dk'
        Write-Host "##[section] $title - email sent to $emailTo ... "`n
    }
}
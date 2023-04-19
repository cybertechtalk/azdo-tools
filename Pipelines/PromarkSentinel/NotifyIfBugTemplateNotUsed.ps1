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
        SELECT * FROM WorkItems WHERE ([System.WorkItemType] = 'Bug')
            $(If ($AreaPath) {"AND [System.AreaPath] IN ('"+($AreaPath.Split(',') -join "','")+"')"})
            AND [System.CreatedDate] <= '$(([System.DateTime]::UtcNow).AddMinutes(-$IdleTime))'
            AND [System.CreatedDate] >= '$(([System.DateTime]::UtcNow).AddMinutes(-$IdleTime-$Interval))'
    "
}

Write-Output $body.query
$bugs = Invoke-RestMethod -Method POST -ContentType application/json -Headers $header -Body ($body | ConvertTo-Json) -Uri $url;
Write-Output ConvertFrom-Json($bugs)

foreach ($bug in $bugs.WorkItems) {
    $item = Invoke-RestMethod -Uri ('https://dev.azure.com/'+$OrganizationName+'/'+$ProjectName+'/_apis/wit/workitems/'+ $bug.id +'?$api-version=7.1-preview.3') -Headers $header -Method Get 
        
    if ([string]::IsNullOrEmpty($item.fields.'company.SD_Group')) {
        $emailTo = $item.fields.'System.CreatedBy'.uniqueName
        $title ='[Promark Sentinel] Bug Template not used in Work Item #' + $item.id
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
        $content = $content.Replace('${EmailMessage}', "Promark sentinel: please use bug template in given bug")

        Send-MailMessage -From "Azure DevOps <azuredevops@company.dk>" -To $emailTo -Subject $title -Body $content -BodyAsHtml -SmtpServer 'securemail.company.dk'
        Write-Host "##[section] $title - email sent to $emailTo ... "`n
    }
    elseif (($item.fields.'company.SD_Group' -eq 'BUG_TEMPLATE_FULL') -and ($item.fields.'Microsoft.VSTS.TCM.ReproSteps' -match '<b>Related Epic, Feature or PBI:<br><br><br></b> </div> </li><li style=\"box-sizing:border-box;\"><div style=\"box-sizing:border-box;\"><b>Has the application previously worked')) {
        $emailTo = $item.fields.'System.CreatedBy'.uniqueName
        $title ='[Promark Sentinel] In "Steps to Reproduce", field "Related Epic, Feature or PBI" is empty in Work Item #' + $item.id
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
        $content = $content.Replace('${EmailMessage}', "Promark sentinel: please fill field: Related Epic, Feature or PBI")

        Send-MailMessage -From "Azure DevOps <azuredevops@company.dk>" -To $emailTo -Subject $title -Body $content -BodyAsHtml -SmtpServer 'securemail.company.dk'
        Write-Host "##[section] $title - email sent to $emailTo ... "`n
    }
}
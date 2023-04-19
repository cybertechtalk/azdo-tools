# $script = $env:HOMEPATH+"\.azure\app_company-project-keyvault-NONPROD.ps1"
# & $script 

$KV_NAME="projectKeyVaultNonProd"
$SUBSCRIPTION="company000000-TESTDMZ"
$KV = az keyvault show -n $KV_NAME --subscription $SUBSCRIPTION
if (!$KV) { 
    Write-Host "$KV_NAME not found in $SUBSCRIPTION" 
    EXIT 0
} 

function Set-Secret {
    param (
        [parameter(Mandatory=$true)]
        [string]$PREFIX,
        [parameter(Mandatory=$true)]
        [string]$SECRETKEY,
        [parameter(Mandatory=$true)]
        [string]$SECRETVALUE
    )

    az keyvault secret set --vault-name $KV_NAME --name $PREFIX-$SECRETKEY --value $SECRETVALUE
    az keyvault secret set-attributes --content-type "companyprojectSecret" --id "https://$KV_NAME.vault.azure.net/secrets/$PREFIX-$SECRETKEY"
    az keyvault secret set-attributes --tags Environment=$PREFIX System=company-project --id "https://$KV_NAME.vault.azure.net/secrets/$PREFIX-$SECRETKEY"
}


$PREFIX="PHX-F"
Set-Secret $PREFIX "AI-CONNECTION-STRING" "InstrumentationKey=97aca7da-838e-45b9-9944-17b39a71cc82;IngestionEndpoint=https://westeurope-2.in.applicationinsights.azure.com/;LiveEndpoint=https://westeurope.livediagnostics.monitor.azure.com/"

$PREFIX="PHX-X"
Set-Secret $PREFIX "AI-CONNECTION-STRING" "InstrumentationKey=97aca7da-838e-45b9-9944-17b39a71cc82;IngestionEndpoint=https://westeurope-2.in.applicationinsights.azure.com/;LiveEndpoint=https://westeurope.livediagnostics.monitor.azure.com/"

$PREFIX="PHX-T"
Set-Secret $PREFIX "AI-CONNECTION-STRING" "InstrumentationKey=44ea5799-5fc7-44a9-9e07-57020486be19;IngestionEndpoint=https://westeurope-1.in.applicationinsights.azure.com/;LiveEndpoint=https://westeurope.livediagnostics.monitor.azure.com/"








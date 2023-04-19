param (
    [Parameter(Mandatory = $true)][string]$DiffsPath
)

$ScriptDirectory = Split-Path -Path $MyInvocation.MyCommand.Definition -Parent
Write-Host $ScriptDirectory
try {
    . ("$ScriptDirectory\Configuration.ps1")
}
catch {
    Write-Error "Error while loading supporting PowerShell Scripts"
    exit 1 
}

$countries = (Get-ChildItem $DiffsPath -Directory).Name

$brokenServices = @{};

foreach ($country in $countries) {
    $searchPath = -join ($DiffsPath, "\", $country, "\", "*.xml")
    Write-Host $searchPath
    $matches = Select-String -Path $searchPath -Pattern "breaks='true'"

    foreach ($match in $matches) {
        $filenameLength = $match.Filename.Length
        # _L1_F1.xml -> 10 characters
        $serviceName = $match.Filename.Substring(0, $filenameLength - 10)

        $key = "$country-$serviceName"
        if(!$brokenServices.Contains($key)) {
            $brokenServices.Add($key, @{ Country = $country; Service = $serviceName})
        }
    }
}

If($brokenServices.Count -gt 0) {
    foreach ($key in $brokenServices.Keys) {
        $entity = $brokenServices[$key]
        $country = $entity['Country']
        $service = $entity['Service']
        Write-Host "##vso[task.logissue type=error;]Environments not compatible for service: [$country][$service]"
    }

    Write-Host "##vso[task.complete result=Failed;]DONE"
    exit 1
}

Write-Host "##vso[task.complete result=Succeeded;]DONE"

exit 0
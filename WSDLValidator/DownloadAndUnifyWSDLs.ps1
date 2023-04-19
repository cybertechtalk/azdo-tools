param (
    [Parameter(Mandatory = $true)][string]$SourcePath,
    [Parameter(Mandatory = $true)][string]$OutputPath,
    [Parameter(Mandatory = $true, HelpMessage="Enter one or more country codes. Available countries: DK, FO, NO, SE")][string[]]$Countries,
    [Parameter(Mandatory = $true, HelpMessage="Positive if WSDLs are to be bundled by environment rather than by service name")][int]$BundleByEnv
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

function Get-WsdlServiceAddress($url) {
    $updatedUrl = $url

    if ($url -match "/TiaAccessControl/SOAP11/SCGenericWebService") {
        $updatedUrl = $updatedUrl -replace "/TiaAccessControl/SOAP11/SCGenericWebService", "/SCGenericWebService"
    }
    elseif ($url -match "/TiaAccessControl/SOAP11") {
        $updatedUrl = $updatedUrl -replace "/TiaAccessControl/SOAP11", "/TiaGenericWebService"
    }

    $updatedUrl = $updatedUrl -replace "/TiaAccessControl/SOAP11", "/TiaGenericWebService"

    return $updatedUrl
}

function Get-SettingsFilePath($countryCode, $environment, $server) {
    if ($environment -eq "Test") {
        return "$SourcePath\appsettings.T.$countryCode.$server.json"
    }
    elseif ($environment -eq "Staging") {
        return "$SourcePath\appsettings.S.$countryCode.json"
    }
    elseif ($environment -eq "Prod") {
        return "$SourcePath\appsettings.P.$countryCode.json"
    }
    else {
        throw "Invalid environment name"
    }
}

function CleanJsonFile($jsonData) {
    $cleanJsonRawData = $jsonRawData -replace '(?m)(?<=^([^"]|"[^"]*")*)//.*'
    $cleanJsonRawData = $cleanJsonRawData -replace '(?ms)/\*.*?\*/' 
    $cleanJsonRawData = $cleanJsonRawData -replace '\,(?=\s*?[\}\]])'

    return $cleanJsonRawData
}

function Get-ServiceUrlsFromSettings($filepath) {
    $hash = [ordered]@{ }
    
    Write-Host "Processing file: " $filepath
    
    $jsonRawData = Get-Content -Raw -Path $filepath
    $cleanJsonRawData = CleanJsonFile $jsonRawData

    $jsonData = $cleanJsonRawData | ConvertFrom-Json

    $services = $jsonData.Services

    foreach ($service in $services.PsObject.Properties) {
        $serviceName = $service.Name
        $serviceUrl = Get-WsdlServiceAddress($service.Value.PsObject.Properties["Url"].Value)

        $hash.Add($serviceName, $serviceUrl)
    }

    return $hash
}

function RemoveVersionFromFileContent($content) {
    return ($content -replace "WSDL version=(.*)?<", "WSDL version='__REMOVED__'<")
}

function RemoveServerAddressFromFileContent($content, $serverAddress) {
    $textToReplace = -join("address location=`"", $serverAddress, "`"")
    $newText = "address location=`"__REMOVED__`""
    return ($content -replace $textToReplace, $newText)
}

function ReplaceImportTypesToTestServerUrl($content, $serverAddress) {
    $serverBaseAddress = $serverAddress.Substring(0, $serverAddress.IndexOf(".company.dk") + 7)

    $textToReplace = -join("xsd:import schemaLocation=`"", $serverBaseAddress)
    $newText = "xsd:import schemaLocation=`"https://esb-dk-0000-c1.tst-ressource.company.dk"
    return ($content -replace $textToReplace, $newText)
}

function UnifyWsdlFile($filePath, $serverAddress) {
    $fileContent = Get-Content $filePath
    $fileContent = RemoveServerAddressFromFileContent $fileContent $serverAddress
    $fileContent = RemoveVersionFromFileContent $fileContent
    $fileContent = ReplaceImportTypesToTestServerUrl $fileContent $serverAddress

    $fileContent | Out-File $filePath
}

function CreateOutPath($server, $serviceName, $country, $outputWSDLPath) {
    if($BundleByEnv -gt 0) {
        return -join ($outputWSDLPath, "\", $server, "\", $country, "\", $serviceName)
    } else {
        return -join ($outputWSDLPath, "\", $country, "\", $serviceName)
    }
}

function CreateFileName($server, $serviceName) {
    return -join ( $(if($BundleByEnv -gt 0) { $serviceName } else { $server }), ".xml")
}

function DownloadContracts($outputWSDLPath) {
    $executionStatus = "Succeeded"

    # [Net.ServicePointManager]::SecurityProtocol = [System.Net.SecurityProtocolType]::Tls
    # [System.Net.ServicePointManager]::ServerCertificateValidationCallback = { $true }
    
    $webClient = new-object System.Net.WebClient

    $progressReal = 0;
    foreach ($country in $Countries) {
        if (!$countryServers.Contains($country)) {
            Write-Host "##vso[task.logissue type=warning;]Invalid country: $country"
            $executionStatus = "SucceededWithIssues"
            Continue
        }

        Write-Host "Downloading contracts for $country"

        foreach ($environment in $countryServers[$country].Keys) {
            foreach ($server in $countryServers[$country][$environment]) {
                $filepath = Get-SettingsFilePath $country $environment $server
                $services = Get-ServiceUrlsFromSettings($filepath)
    
                foreach ($serviceName in $services.Keys) {
                    $numberOfServices = $services.Count

                    if($services[$serviceName] -notmatch "\S") {
                        Write-Host "##vso[task.logissue type=warning;]Url for service '$serviceName' for [$environment][$server] not specified"
                        Continue
                    }

                    $serviceOutPath = CreateOutPath $server $serviceName $country $outputWSDLPath
                    If (!(test-path $serviceOutPath)) {
                        New-Item -ItemType Directory -Path $serviceOutPath | Out-Null
                    }
                
                    $fileName = CreateFileName $server $serviceName
                    $outputFile = -join ($serviceOutPath, "\", $fileName)
                    $wsdlEndpoint = -join ($services[$serviceName], "?wsdl")

                    try {
                        $response = $webClient.DownloadString($wsdlEndpoint)
                        $response | Out-File $outputFile

                        Write-Host "File created at '$outputFile' for [$environment][$server]"
                        UnifyWsdlFile $outputFile $services[$serviceName]

                        $progressReal = $progressReal +  (100 / (4 * $numberOfServices * $Countries.Length)) # 4 environments per country in total
                        $progress = [int]$progressReal
                        Write-Host "##vso[task.setprogress value=$progress;]$serviceName for [$country][$server] downloaded"  
                    }
                    catch {
                        Write-Host $_
                        Write-Host "##vso[task.logissue type=warning;]Could not download WSDL for [$country][$server] $serviceName`: $wsdlEndpoint"
                        $executionStatus = "SucceededWithIssues"
                    }    
                }
            }
        }   
    }

    return $executionStatus
}

If (test-path $OutputPath) {
    Remove-Item $OutputPath -Recurse -ErrorAction Ignore
}

New-Item -ItemType Directory -Path $OutputPath

$result = DownloadContracts $OutputPath

Write-Host "##vso[task.complete result=$result;]DONE"
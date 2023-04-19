param (
    [Parameter(Mandatory = $true)][string]$WSDLPath,
    [Parameter(Mandatory = $true)][string]$OutputPath,
    [Parameter(Mandatory = $true)][string]$DiffToolPath
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

function CompareEnvsContracts($serviceName, $countryInputPath, $countryDiffReportPath, $originalEnv, $newEnv) {
    $originalEnvWSDLPath = -join ($countryInputPath, "\", $serviceName, "\", $originalEnv, ".xml")
    $newEnvWSDLPath = -join ($countryInputPath, "\", $serviceName, "\", $newEnv, ".xml")

    If ((test-path $originalEnvWSDLPath) -eq $false) {
        Write-Host "Missing file: $originalEnvWSDLPath"
        return $true
    }

    If ((test-path $newEnvWSDLPath) -eq $false) {
        Write-Host "Missing file: $newEnvWSDLPath"
        return $true
    }

    $standardOutputPath = "$countryInputPath\$serviceName\stdout-$originalEnv-$newEnv.txt"
    $errorOutputPath = "$countryInputPath\$serviceName\errout-$originalEnv-$newEnv.txt"

    $args = "$originalEnvWSDLPath $newEnvWSDLPath $countryDiffReportPath"
    Write-Host "Executing WsdlDiff with arguments:" $args
    Start-Process $DiffToolPath $args -Wait -NoNewWindow -RedirectStandardOutput $standardOutputPath -RedirectStandardError $errorOutputPath
    
    $outputHtmlFileName = -join ($serviceName, "_", $originalEnv, "_", $newEnv, ".html")
    $outputXmlFileName = -join ($serviceName, "_", $originalEnv, "_", $newEnv, ".xml")
    $diffHtmlFilePath = -join ($countryDiffReportPath, "\", "diff-report.html")
    $diffXmlFilePath = -join ($countryDiffReportPath, "\", "diff-report.xml")

    If ((test-path $diffHtmlFilePath) -eq $false) {
        Write-Host "##vso[task.logissue type=warning;]Diff html file not generated for $serviceName $originalEnv $newEnv"
        return $false
    }
    ElseIf ((test-path $diffXmlFilePath) -eq $false) {
        Write-Host "##vso[task.logissue type=warning;]Diff xml file not generated for $serviceName $originalEnv $newEnv"
        return $false
    }
    Else {
        Rename-Item -Path $diffHtmlFilePath -NewName $outputHtmlFileName | Out-Null
        Rename-Item -Path $diffXmlFilePath -NewName $outputXmlFileName | Out-Null
    } 

    return $true
}

function CompareContracts($inputPath, $diffReportPath) {
    $executionStatus = "Succeeded"

    $countries = (Get-ChildItem $inputPath -Directory).Name

    $progressReal = 0;
    foreach ($country in $countries) {
        Write-Host "Comparing contracts for $country"

        $countryInputPath = -join ($inputPath, "\", $country)
        $services = (Get-ChildItem $countryInputPath -Directory).Name

        $countryDiffReportPath = -join ($diffReportPath, "\", $country)
        If (!(test-path $countryDiffReportPath)) {
            New-Item -ItemType Directory -Path $countryDiffReportPath | Out-Null
            Write-Host "Directory '$countryDiffReportPath' created"
        }

        $envs = @("Prod", "Staging", "Test")

        $servicesCount = $services.Count;

        $index = 1;
        foreach ($service in $services) {
            Write-Host "Processing $index/$servicesCount | $service"
            for ($i = 0; $i -lt ($envs.Count - 1); $i++) {
                foreach ($firstEnv in $countryServers[$country][$envs[$i]]) {
                    foreach ($secondEnv in $countryServers[$country][$envs[$i+1]]) {
                        $result = CompareEnvsContracts $service $countryInputPath $countryDiffReportPath $firstEnv $secondEnv

                        if(!$result) {
                            $executionStatus = "SucceededWithIssues"
                        }
                    }
                }
            }

            $index = $index + 1;
            $progressReal = $progressReal + (100 / ($countries.Count * $servicesCount))
            $progress = [int]$progressReal
            Write-Host "##vso[task.setprogress value=$progress;]Compare completed for [$country][$service]"  
        }        
    }

    return $executionStatus
}

If (test-path $OutputPath) {
    Remove-Item $OutputPath -Recurse -ErrorAction Ignore
}

New-Item -ItemType Directory -Path $OutputPath

Write-Host "WSDLPath: $WSDLPath"
Write-Host "OutputPath: $OutputPath"
Write-Host "DiffToolPath: $DiffToolPath"

$result = CompareContracts $WSDLPath $OutputPath

Write-Host "##vso[task.complete result=$result;]DONE"
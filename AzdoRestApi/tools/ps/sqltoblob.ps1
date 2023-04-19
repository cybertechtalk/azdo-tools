$secureString = convertto-securestring "B@nkOfth£future!" -asplaintext -force
$resourceGroupName = "RG-company000000-DMZ-project-PROD-02"
$serverName = "company-project-prod-sqlserver"

$databaseName = "company-project-prod-db-core.web(6486.0.0-Release.29216_9992)"

$importRequest = New-AzSqlDatabaseImport -ResourceGroupName $resourceGroupName `
    -ServerName $serverName `
    -DatabaseName $databaseName `
    -DatabaseMaxSizeBytes "262144000" `
    -StorageKeyType "StorageAccessKey" `
    -StorageKey "QAz914fQTKJiE+bc0PA3OgsZJQmxvky8dvoKcCMQZ60F+ZNGh7ebRZsk8qZrEI5QlTmverJu0wOHS61G3BfzHQ==" `
    -StorageUri "https://companyprojectprodstorage.blob.core.windows.net/sqldbbackup/test.bacpac" `
    -Edition "Standard" `
    -ServiceObjectiveName "S3" `
    -AdministratorLogin "devsqluser" `
    -AdministratorLoginPassword $secureString


$waitDelay = 5
while (($importRequest | Get-AzSqlDatabaseImportExportStatus).Status -eq 'InProgress') {
    ($importRequest | Get-AzSqlDatabaseImportExportStatus).StatusMessage
    Start-Sleep $waitDelay
}


# Output results
$result = $importRequest | Get-AzSqlDatabaseImportExportStatus
$result
if ($result.Status -eq 'Succeeded') {
    
    Write-Host "Database Deployed"
}
else
{
    Write-Host "Database did not deploy '$($result.Status)'-'$($result.ErrorMessage)'"
    Throw $result.ErrorMessage
}

company-project-preprod-sqlserver: preprodsqladminuser // -tf7tQpZY3kCn~dpFEnf
company-project-prod-sqlserver: prodadminsqluser // 6uj:cd5c)AyL58Uu
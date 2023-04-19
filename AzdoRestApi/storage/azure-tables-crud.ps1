[CmdletBinding()]
param (
    [string]$storageAccount,
    [string]$accesskey
)

function GetTableEntityAll($TableName) {
    $version = "2017-04-17"
    $resource = "$tableName"
    $table_url = "https://$storageAccount.table.core.windows.net/$resource"
    $GMTTime = (Get-Date).ToUniversalTime().toString('R')
    $stringToSign = "$GMTTime`n/$storageAccount/$resource"
    $hmacsha = New-Object System.Security.Cryptography.HMACSHA256
    $hmacsha.key = [Convert]::FromBase64String($accesskey)
    $signature = $hmacsha.ComputeHash([Text.Encoding]::UTF8.GetBytes($stringToSign))
    $signature = [Convert]::ToBase64String($signature)
    $headers = @{
        'x-ms-date'    = $GMTTime
        Authorization  = "SharedKeyLite " + $storageAccount + ":" + $signature
        "x-ms-version" = $version
        Accept         = "application/json;odata=fullmetadata"
    }
    $item = Invoke-RestMethod -Method GET -Uri $table_url -Headers $headers -ContentType application/json
    return $item.value
}

function GetTableEntity($TableName, $Filter) {
    $version = "2017-04-17"
    $resource = "$tableName"
    $table_url = "https://$storageAccount.table.core.windows.net/$resource" + '?$filter=' + $filter
    $GMTTime = (Get-Date).ToUniversalTime().toString('R')
    $stringToSign = "$GMTTime`n/$storageAccount/$resource"
    $hmacsha = New-Object System.Security.Cryptography.HMACSHA256
    $hmacsha.key = [Convert]::FromBase64String($accesskey)
    $signature = $hmacsha.ComputeHash([Text.Encoding]::UTF8.GetBytes($stringToSign))
    $signature = [Convert]::ToBase64String($signature)
    $headers = @{
        'x-ms-date'    = $GMTTime
        Authorization  = "SharedKeyLite " + $storageAccount + ":" + $signature
        "x-ms-version" = $version
        Accept         = "application/json;odata=fullmetadata"
    }
    $item = Invoke-RestMethod -Method GET -Uri $table_url -Headers $headers -ContentType application/json
    return $item.value
}
 
function PutTableEntity($TableName, $entity) {
    $version = "2017-04-17"
    $resource = "$tableName(PartitionKey='$($entity.PartitionKey)',RowKey='$($entity.Rowkey)')"
    $table_url = "https://$storageAccount.table.core.windows.net/$resource"
    $GMTTime = (Get-Date).ToUniversalTime().toString('R')
    $stringToSign = "$GMTTime`n/$storageAccount/$resource"
    $hmacsha = New-Object System.Security.Cryptography.HMACSHA256
    $hmacsha.key = [Convert]::FromBase64String($accesskey)
    $signature = $hmacsha.ComputeHash([Text.Encoding]::UTF8.GetBytes($stringToSign))
    $signature = [Convert]::ToBase64String($signature)
    $headers = @{
        'x-ms-date'    = $GMTTime
        Authorization  = "SharedKeyLite " + $storageAccount + ":" + $signature
        "x-ms-version" = $version
        Accept         = "application/json;odata=fullmetadata"
    }
    $body = $entity | ConvertTo-Json
    $item = Invoke-RestMethod -Method PUT -Uri $table_url -Headers $headers -Body $body -ContentType application/json
}
 
function MergeTableEntity($TableName, $entity) {
    $version = "2017-04-17"
    $resource = "$tableName(PartitionKey='$($entity.PartitionKey)',RowKey='$($entity.Rowkey)')"
    $table_url = "https://$storageAccount.table.core.windows.net/$resource"
    $GMTTime = (Get-Date).ToUniversalTime().toString('R')
    $stringToSign = "$GMTTime`n/$storageAccount/$resource"
    $hmacsha = New-Object System.Security.Cryptography.HMACSHA256
    $hmacsha.key = [Convert]::FromBase64String($accesskey)
    $signature = $hmacsha.ComputeHash([Text.Encoding]::UTF8.GetBytes($stringToSign))
    $signature = [Convert]::ToBase64String($signature)
    $body = $entity | ConvertTo-Json
    $headers = @{
        'x-ms-date'      = $GMTTime
        Authorization    = "SharedKeyLite " + $storageAccount + ":" + $signature
        "x-ms-version"   = $version
        Accept           = "application/json;odata=minimalmetadata"
        'If-Match'       = "*"
        'Content-Length' = $body.length
    }
    $item = Invoke-RestMethod -Method MERGE -Uri $table_url -Headers $headers -ContentType application/json -Body $body
 
}
 
function DeleteTableEntity($TableName, $entity) {
    $version = "2017-04-17"
    $resource = "$tableName(PartitionKey='$($entity.PartitionKey)',RowKey='$($entity.Rowkey)')"
    $table_url = "https://$storageAccount.table.core.windows.net/$resource"
    $GMTTime = (Get-Date).ToUniversalTime().toString('R')
    $stringToSign = "$GMTTime`n/$storageAccount/$resource"
    $hmacsha = New-Object System.Security.Cryptography.HMACSHA256
    $hmacsha.key = [Convert]::FromBase64String($accesskey)
    $signature = $hmacsha.ComputeHash([Text.Encoding]::UTF8.GetBytes($stringToSign))
    $signature = [Convert]::ToBase64String($signature)
    $headers = @{
        'x-ms-date'    = $GMTTime
        Authorization  = "SharedKeyLite " + $storageAccount + ":" + $signature
        "x-ms-version" = $version
        Accept         = "application/json;odata=minimalmetadata"
        'If-Match'     = "*"
    }
    $item = Invoke-RestMethod -Method DELETE -Uri $table_url -Headers $headers -ContentType application/http
 
}
 
 
# $body = @{
#     RowKey       = "$(Build.BuildId)" #AZDO build id 
#     PartitionKey = "01" #FT enviroment 01-20
#     From      = (Get-Date).ToUniversalTime().toString('R')
#     To         = (Get-Date).ToUniversalTime().AddDays(7).toString('R')
#     Author    = ''
# }
 
# Write-Host "Getting all table entities"
# $tableItems = GetTableEntityAll -TableName featuretestreservation

# Write-Host "Getting all table entities"
# $tableItems = GetTableEntity -TableName featuretestreservation ` 
#    -Filter "PartitionKey%20eq%20'01'%20and%20From%20eq%20datetime'$(($tableItems[0].From).toString('yyyy-MM-ddTHH:mm:ssZ'))'"
  
# Write-Host "Creating a new table entity"
# PutTableEntity -TableName "featuretestreservation" -entity $body
 
# Write-Host "Merging with an existing table entity"
# MergeTableEntity -TableName "featuretestreservation" -RowKey $body.RowKey -PartitionKey $body.PartitionKey -entity $body
 
# Write-Host "Deleting an existing table entity"
# DeleteTableEntity -TableName "featuretestreservation" -RowKey $body.RowKey -PartitionKey $body.PartitionKey
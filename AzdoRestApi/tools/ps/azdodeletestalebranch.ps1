# az extension add --name azure-devops
# az devops configure --defaults organization=https://dev.azure.com/company-prod/
# az login

param(
    [string]$Project = "projecting",
    [string]$Repository = "company-project",
    [object]$ExcludeBranches = @("release/", "master"),
    [int]$DaysDeleteBefore = -365,
    [int]$BatchSize = 0,
    [switch]$WhatIf
)

if (-not $WhatIf) {
    $input = Read-Host -Prompt 'You are about deleting stale branches permanently. Use -WhatIf instead. Continue? [Y/N]'
    if ($input -ne 'Y') {
        return
    }
}

$startTime = [DateTime]::Now
$dateTimeBeforeToDelete = $startTime.AddDays($daysDeleteBefore)
Write-Host ("is dry run: {0}" -f $WhatIf)
Write-Host ("start time: {0}" -f $startTime)
Write-Host ("batch size: {0}" -f $BatchSize)
Write-Host ("delete branches before {0}" -f (get-date $dateTimeBeforeToDelete))

$refs = (az repos ref list --project $project --repository $repository --filter heads) | ConvertFrom-Json

if ($refs.count -eq 0) {
    Write-Host "[INFO] No refs found"
    return;
}

if ($BatchSize -gt 0) {
   $refs = $refs | select -First $BatchSize
}

$toDeleteBranches = @()
Write-Host "$($refs.count) refs founds"

[int]$i = 0
foreach ($ref in $refs) {
    $i++

    if ($ref.name -match ($excludeBranches -join '|')) {
        continue;
    }

    $objectId = $ref.objectId
    
    # fetch individual commit details
    $commit = az devops invoke `
        --area git `
        --resource commits `
        --route-parameters `
        project=$project `
        repositoryId=$repository `
        commitId=$objectId |
    ConvertFrom-Json

    Write-Host "[INFO] $i/$($refs.count): $($ref.name) | commitdate: $($commit.push.date) | by: $($commit.committer.email)"
    Write-Progress -Activity "Processing" -Status "$([math]::Round($i/$refs.count*100))% done" -PercentComplete $([math]::Round($i/$refs.count*100))
    
    $toDelete = [PSCustomObject]@{ 
        objectId     = $objectId
        name         = $ref.name
        creator      = $ref.creator.uniqueName
        lastAuthor   = $commit.committer.email
        lastModified = $commit.push.date
    }
    $toDeleteBranches += , $toDelete
}
"time elapsed: {0:HH:mm:ss}" -f ([datetime]($(get-date) - $startTime).Ticks)

$toDeleteBranches = $toDeleteBranches | Where-Object { (get-date $_.lastModified) -lt (get-date $dateTimeBeforeToDelete) }

if ($toDeleteBranches.count -eq 0) {
    Write-Host "[INFO] No staled branches to delete"
    return;
}

Write-Host "$($toDeleteBranches.count) branches founds older than $daysDeleteBefore days"
if ($WhatIf) {
    $logFile = "$($startTime.ToString('yyyy-MM-dd-hh-mm-ss'))-report"
    Write-Host "Log available under $($pwd.Path)\$logFile"
    $toDeleteBranches > "$logFile.txt"
    $toDeleteBranches | Export-CSV "$logFile.csv"

    Write-Host "$($refs.count) branches founds"
    Write-Host "[INFO] DO NOT USE -WhatIf to delete permanently"
    return;
}

[int]$i = 0
$toDeleteBranches |
ForEach-Object {
    $i++
    Write-Host ("##[warning]deleting staled branch: name={0} - id={1} - lastModified={2}" -f $_.name, $_.objectId, $_.lastModified)
    $result = az repos ref delete `
        --name $_.name `
        --object-id $_.objectId `
        --project $project `
        --repository $repository |
    ConvertFrom-Json
    Write-Host ("##[section] {0}" -f $result.updateStatus)
    Write-Progress -Activity "Deleting" -Status "$([math]::Round($i/$toDeleteBranches.count*100))% done" -PercentComplete $([math]::Round($i/$toDeleteBranches.count*100))
}
"time elapsed: {0:HH:mm:ss}" -f ([datetime]($(get-date) - $startTime).Ticks)
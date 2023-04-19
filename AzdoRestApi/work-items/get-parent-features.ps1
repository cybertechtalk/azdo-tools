<#
  .SYNOPSIS
  Expand the given PBIs with parent information.

  .DESCRIPTION
  The script reads the input list of PBI/BUGs and produces new list containing both the PBI/BUG and it's parent information.

  .PARAMETER f
  Specifies the path to file, each line containing a PBI/BUG id (resolved using regex). 

  .INPUTS
  None

  .OUTPUTS
  Table containing PBI/BUG and it's parent information

  .EXAMPLE
  PS> .\get-parent-features.ps1 < pbi-list.txt
#>

[CmdletBinding()]

param(
    [Parameter(Mandatory=$true)]
    [Alias('f')]
    [string] $file
)

$token = ""  # your AZDO Personal Access Token - needs at least Read access to work items and repositories
$user = "user@company.dk" # your user
$b64auth = [Convert]::ToBase64String([Text.Encoding]::ASCII.GetBytes(("{0}:{1}" -f $user,$token)))
$azdoPrefix = "https://company-prod.visualstudio.com/projecting/_apis/"
$repoId = "ae0ae003-b3fb-44a6-8f3c-9e4fe49116b7"

function Invoke-AZDO($url) {
    Invoke-RestMethod -Headers @{Authorization=("Basic {0}" -f $b64auth)} -Method Get -ContentType "application/json" -Uri $url
}

function Invoke-AZDO-Get-WorkItem($workItemId) {
    Invoke-AZDO "${azdoPrefix}/wit/workitems/${workItemId}?`$expand=Relations&api-version=6.0"
}

function Show-Busy { 
    Write-Host -NoNewline '.' 
}


$items = (Get-Content -Path $file) |
    Select-String -Pattern "(\d{5,6})" -AllMatches | 
    ForEach-Object {
        
        Show-Busy

        $workItemId = $_.matches.groups[1].value
        $workItem = Invoke-AZDO-Get-WorkItem $workItemId
        
        $result = @{ 
            "id"=$workItemId; 
            "type"=$workItem.fields.'System.WorkItemType'; 
            "status"=$workItem.fields.'System.State';
            "title"=$workItem.fields.'System.Title'
        }
        
        $parentUrl = $workItem.relations.Where{$_.attributes.name -eq 'Parent'}[0].url
        if($parentUrl) {
            $parentId = $parentUrl.Split("/")[-1]
            $parent = Invoke-AZDO-Get-WorkItem $parentId
            $result = $result + @{ 
                "parentId"=$parentId
                "parentType"=$parent.fields.'System.WorkItemType'
                "parentStatus"=$parent.fields.'System.State'
                "parentTitle"=$parent.fields.'System.Title'
            }
        }

        $result
}

Write-Output "Id;Type;Status;Title;ParentId;ParentType;ParentStatus;ParentTitle;"
$items.ForEach{ Write-Output "$($_.id);$($_.type);$($_.status);$($_.title);$($_.parentId);$($_.parentType);$($_.parentStatus);$($_.parentTitle)" }
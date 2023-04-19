function TfsRequest {
  param([Parameter(Mandatory)][string] $RestEndpoint, 
  [Parameter(Mandatory=$false)][string] $Method="GET", 
  [Parameter(Mandatory=$false)] $RequestBody,
  [Parameter(Mandatory=$false)][string] $ContentType,
  [Parameter(Mandatory=$false)][string] $AuthToken,
  [Parameter(Mandatory=$false)][bool] $Array=$False,
  [Parameter(Mandatory=$false)][string] $Project=$env:SYSTEM_TEAMPROJECT)
  [Net.ServicePointManager]::SecurityProtocol = [Net.SecurityProtocolType]::Tls12;
  $Url = "$env:SYSTEM_TEAMFOUNDATIONCOLLECTIONURI$Project/_apis/$RestEndpoint";
  $Headers = @{};
  If (-Not ([string]::IsNullOrEmpty($ContentType))) { $Headers.add("Content-Type", $ContentType) };
  If (-Not ([string]::IsNullOrEmpty($AuthToken))) { $Headers.add("Authorization", "Basic $AuthToken") };
  If (-Not ([string]::IsNullOrEmpty($RequestBody))) { 
    $RequestBodyJson = ($RequestBody | ConvertTo-Json -Depth 100);
    If ($Array) { $RequestBodyJson = "[$RequestBodyJson]"; }
  }
  $Result = Invoke-RestMethod -Method $Method -UsedefaultCredential -Uri $Url -Headers $Headers -Body $RequestBodyJson;
  return $Result;
}

function GetPullRequest {
  param([Parameter(Mandatory)] $Repository, 
  [Parameter(Mandatory)][string] $From, 
  [Parameter(Mandatory)][string] $To,
  [Parameter(Mandatory=$false)][string] $AuthToken,
  [Parameter(Mandatory=$false)][string] $Project=$env:SYSTEM_TEAMPROJECT)
  Write-Host "[INFO] Checking if there is an existing PR in $Repository from $From to $To";
  $PullRequestSearchResult = TfsRequest -AuthToken $AuthToken -Project $Project -RestEndpoint "git/repositories/$Repository/pullRequests?searchCriteria.sourceRefName=refs/heads/$From&searchCriteria.targetRefName=refs/heads/$To&searchCriteria.status=active&api-version=4.1";
  If ($PullRequestSearchResult.count -eq 1) {
    return $PullRequestSearchResult.value;
  } Else {
    return $null;
  }
}

function CreatePullRequest {
  param([Parameter(Mandatory)] $Repository, 
  [Parameter(Mandatory)][string] $From, 
  [Parameter(Mandatory)][string] $To,
  [Parameter(Mandatory)][string] $Title,
  [Parameter(Mandatory)][string] $Description,
  [Parameter(Mandatory)][string] $AuthToken,
  [Parameter(Mandatory=$false)][string] $Project=$env:SYSTEM_TEAMPROJECT)
  $Repo = $Repository.repo;
  $Reviewers = $Repository.reviewers;
  $TFS_PROJECT_URL = "$env:SYSTEM_TEAMFOUNDATIONCOLLECTIONURI/$Project"
  $PullRequest = GetPullRequest -AuthToken $AuthToken -Repository $Repo -From $From -To $To -Project $Project;
  If ($null -ne $PullRequest) {
    $PullRequestId = $PullRequest.pullRequestId;
    $PullRequestUrl = "$TFS_PROJECT_URL/_git/$Repo/pullrequest/$PullRequestId";
    Write-Host "[INFO] Retrieved a PR. See: $PullRequestUrl";
    return $PullRequestId;
  }
  Write-Host "[INFO] Beginning creating a PR in $Repo from $From to $To";
  $PullRequestBody = @{
        "sourceRefName" = "refs/heads/$From"
        "targetRefName" = "refs/heads/$To"
        "title" = $Title
        "description" = $Description
        "reviewers" = $Reviewers 
    };
    Write-Host "[INFO] Sending request to TFS REST API";
    $PullRequestResult = TfsRequest -Method POST -AuthToken $AuthToken -Project $Project -ContentType "application/json" -RequestBody $PullRequestBody -RestEndpoint "git/repositories/$Repo/pullRequests?api-version=4.1";
    $PullRequestId = $PullRequestResult.pullRequestId;
    $PullRequestUrl = "$TFS_PROJECT_URL/_git/$Repo/pullrequest/$PullRequestId";
    Write-Host "[INFO] Created a PR. See: $PullRequestUrl";
    return $PullRequestId;
}

# function MergePullRequest {
#   param([Parameter(Mandatory)] $Repo, 
#   [Parameter(Mandatory)] $PullRequestId, 
#   [Parameter(Mandatory)] [string] $MergeCommitMessage,
#   [Parameter()] [string] $BypassReason,
#   [Parameter(Mandatory=$false)][string] $Project=$env:SYSTEM_TEAMPROJECT)
#   $Repository = $Repo.repo;
#   Write-Host "[INFO] Getting the details of PR $PullRequestId";
#   $PullRequestEndpoint = "git/repositories/$Repository/pullRequests/${PullRequestId}?api-version=4.1";
#   $PullRequest = TfsRequest -Project $Project -RestEndpoint $PullRequestEndpoint;
#   Write-Host "[INFO] Merging the Pull Request $PullRequestUrl";
#   $PullRequestBody = @{
#     "status" = "completed"
#     "lastMergeSourceCommit" = $PullRequest.lastMergeSourceCommit
#     "completionOptions" = @{
#       "deleteSourceBranch" = "false"
#       "mergeCommitMessage" = $MergeCommitMessage
#       "squashMerge" = "false"
#       "bypassPolicy" = If ([string]::IsNullOrEmpty($BypassReason)) { "false" } Else { "true" }
#       "bypassReason" = $BypassReason
#       "transitionWorkItems" = "true"
#     }
#   };
#   $PullRequestResult = TfsRequest -Method PATCH -Project $Project -ContentType "application/json" -RequestBody $PullRequestBody -RestEndpoint $PullRequestEndpoint;
# }

# function GetPrWorkitems {
#   param([Parameter(Mandatory)] $Repo, 
#   [Parameter(Mandatory)] $PullRequestId,
#   [Parameter(Mandatory=$false)][string] $Project=$env:SYSTEM_TEAMPROJECT)
#   $Repository = $Repo.repo;
#   Write-Host "[INFO] Retrieving workitems from PR $PullRequestId";
#   $Workitems = TfsRequest -Project $Project -RestEndpoint "git/repositories/$Repository/pullRequests/${PullRequestId}/workitems?api-version=4.1";
#   return $Workitems.value;
# }

# function GetWorkItem {
#   param([Parameter(Mandatory)] $ItemId,
#   [Parameter(Mandatory=$false)][string] $Project=$env:SYSTEM_TEAMPROJECT)
#   $Workitem = TfsRequest -Project $Project -RestEndpoint "wit/workItems/${ItemId}?api-version=4.1";
#   return $Workitem;
# }

# function GetParentWorkItem {
#   param([Parameter(Mandatory)] $ItemId,
#   [Parameter(Mandatory=$false)][string] $Project=$env:SYSTEM_TEAMPROJECT)
#   Write-Host "[INFO] Retrieving parent for $ItemId";
#   $Workitem = TfsRequest -Project $Project -RestEndpoint "wit/workItems/${ItemId}?`$expand=Relations&api-version=4.1";
#   foreach ($Link in $Workitem.relations) {
#     If ($Link.rel -eq "System.LinkTypes.Hierarchy-Reverse") {
#       $Parent = Invoke-RestMethod -Method GET -UsedefaultCredential -Uri $Link.url;
#       return $Parent;
#     }
#   }
#   return $null;
# }

# function UpdateWorkItem {
#   param([Parameter(Mandatory)] $Item, 
#   [Parameter(Mandatory)] [string] $State,
#   [Parameter(Mandatory=$false)][string] $Project=$env:SYSTEM_TEAMPROJECT)
#   If ($Item.fields."System.State" -ne $State -And $Item.fields."System.State" -ne "Removed") {
#     $ItemId = $Item.id;
#     $WorkItemBody = @(
#       @{
#         "op" = "replace"
#         "path" = "/fields/System.State"
#         "value" = $State
#         }
#     );
#     $UpdateResult = TfsRequest -Method PATCH -Project $Project -RestEndpoint "wit/workItems/${ItemId}?api-version=4.1" -ContentType "application/json-patch+json" -Array $True -RequestBody $WorkItemBody;
#     Write-Host "[INFO] Changed state of $ItemId to $State";
#   }
# }

# function UpdateChildren {
#   param([Parameter(Mandatory)] $ItemId,
#   [Parameter(Mandatory)] [string] $State,
#   [Parameter(Mandatory=$false)][string] $Project=$env:SYSTEM_TEAMPROJECT)
#   Write-Host "[INFO] Retrieving children for $ItemId";
#   $Workitem = TfsRequest -Project $Project -RestEndpoint "wit/workItems/${ItemId}?`$expand=Relations&api-version=4.1";
#   foreach ($Link in $Workitem.relations) {
#     If ($Link.rel -eq "System.LinkTypes.Hierarchy-Forward") {
#       Write-Host "[IFNO] Getting details of ${Link.url}";
#       $Child = Invoke-RestMethod -Method GET -UsedefaultCredential -Uri $Link.url;
#       UpdateWorkItem -Item $Child -State "Done" -Project $Project;
#     }
#   }
#   return $null;
# }

# function UpdatePrWorkItems {
#   param([Parameter(Mandatory)] $Repo, 
#   [Parameter(Mandatory)] $PullRequestId, 
#   [Parameter(Mandatory)] [string] $State,
#   [Parameter(Mandatory=$false)][string] $Project=$env:SYSTEM_TEAMPROJECT)
#   Write-Host "[INFO] Updating tasks on PR $PullRequestId to $State";
#   $Workitems = GetPrWorkitems -Repo $Repo -PullRequestId $PullRequestId -Project $Project;
#   foreach ($Item in $Workitems) {
#     $Task = GetWorkItem -ItemId $Item.id -Project $Project;
#     UpdateWorkItem -Item $Task -State "Done" -Project $Project;
    
#     $Parent = GetParentWorkItem -ItemId $Item.id -Project $Project;
#     If ($Parent -ne $null) {
#       UpdateWorkItem -Item $Parent -State $State -Project $Project;
#       UpdateChildren -ItemId $Parent.id -State "Done" -Project $Project;
#     }
#   }
# }
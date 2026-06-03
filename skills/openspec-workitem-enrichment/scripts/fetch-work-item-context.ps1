param(
    [Parameter(Mandatory = $true)]
    [int]$WorkItemId,
    [string]$Org,
    [string]$Project,
    [string]$RepoRoot = (Get-Location).Path,
    [string]$RemoteName = "origin",
    [int]$MaxParentDepth = 10
)

$ErrorActionPreference = 'Stop'

function Get-PatFileErrorMessage {
    param([string]$PatFile)

    $userProfile = Get-UserProfilePath
    $patDir = Join-Path $userProfile '.config\linksoft-skills'

    return @"
Azure DevOps PAT configuration file was not found or is invalid.

Your user profile resolves to:
  $userProfile

Create this exact directory:
  $patDir

Inside that directory, create this exact file:
  azure-devops.env

The full file path must be:
  $PatFile

The file must contain exactly one line:
  AZURE_DEVOPS_PAT=<your Azure DevOps PAT>

Do not add quotes around the token. Do not add extra lines. Do not commit this file to git.

When creating the PAT in Azure DevOps, grant the minimum required scope:
  Work Items: Read

This corresponds to the Azure DevOps REST API vso.work permission, which allows reading work items, comments, queries, boards, area paths, and iteration paths. The token does not need write permissions, Code permissions, Build permissions, Packaging permissions, or full access for this skill.

Optional PowerShell commands to create it:
  New-Item -ItemType Directory -Force "$patDir"
  Set-Content -NoNewline -Path "$PatFile" -Value "AZURE_DEVOPS_PAT=<your Azure DevOps PAT>"

Replace <your Azure DevOps PAT> with the actual token before saving the file or running the command.

Example file contents:
  AZURE_DEVOPS_PAT=abcdefghijklmnopqrstuvwxyzABCDEFGHIJKLMNOPQRSTUVWXYZ0123456789AZDOabcd
"@
}

function Get-UserProfilePath {
    if ($env:USERPROFILE) {
        return $env:USERPROFILE
    }

    $profilePath = [Environment]::GetFolderPath('UserProfile')
    if ($profilePath) {
        return $profilePath
    }

    if ($HOME) {
        return $HOME
    }

    throw 'Unable to resolve the user profile directory. On Windows, USERPROFILE must be set. On Linux/macOS, HOME must be set.'
}

function Throw-PatFileError {
    param([string]$PatFile)

    [Console]::Error.WriteLine((Get-PatFileErrorMessage -PatFile $PatFile))
    throw 'Azure DevOps PAT configuration file was not found or is invalid. See setup instructions above.'
}

function Get-AzureDevOpsPat {
    $userProfile = Get-UserProfilePath
    $patFile = Join-Path $userProfile '.config\linksoft-skills\azure-devops.env'
    if (-not (Test-Path -LiteralPath $patFile -PathType Leaf)) {
        Throw-PatFileError -PatFile $patFile
    }

    $lines = @(Get-Content -LiteralPath $patFile | ForEach-Object { $_.Trim() })

    if ($lines.Count -ne 1 -or -not $lines[0].StartsWith('AZURE_DEVOPS_PAT=')) {
        Throw-PatFileError -PatFile $patFile
    }

    $value = $lines[0].Substring('AZURE_DEVOPS_PAT='.Length).Trim()
    if (-not $value -or ($value.StartsWith('"') -and $value.EndsWith('"')) -or ($value.StartsWith("'") -and $value.EndsWith("'"))) {
        Throw-PatFileError -PatFile $patFile
    }

    return [pscustomobject]@{
        Pat = $value
        Path = $patFile
    }
}

function Invoke-AdoRestJson {
    param(
        [Parameter(Mandatory = $true)]
        [string]$Uri,
        [Parameter(Mandatory = $true)]
        [string]$Pat
    )

    $auth = [Convert]::ToBase64String([Text.Encoding]::ASCII.GetBytes(":" + $Pat))
    try {
        return Invoke-RestMethod -Method Get -Uri $Uri -Headers @{ Authorization = "Basic $auth"; Accept = 'application/json' }
    } catch {
        $message = $_.Exception.Message
        if ($_.ErrorDetails -and $_.ErrorDetails.Message) {
            $message = $_.ErrorDetails.Message
        }
        throw "Azure DevOps REST API request failed: $Uri`n$message"
    }
}

$scriptDir = Split-Path -Parent $MyInvocation.MyCommand.Path
$patConfig = Get-AzureDevOpsPat

if (-not $Org -or -not $Project) {
    $context = & "$scriptDir/infer-azure-devops-context.ps1" -RepoRoot $RepoRoot -RemoteName $RemoteName | ConvertFrom-Json
    if (-not $Org) { $Org = $context.org }
    if (-not $Project) { $Project = $context.project }
} else {
    $context = [pscustomobject]@{
        org = $Org
        project = $Project
    }
}

$orgUrl = if ($context.collectionUri) { $context.collectionUri.TrimEnd('/') } else { "https://dev.azure.com/$Org" }

$wiql = "SELECT [System.Id], [System.Title], [System.State] FROM WorkItems WHERE [System.Id] = $WorkItemId ORDER BY [System.ChangedDate] DESC"
$encodedProject = [System.Uri]::EscapeDataString($Project)

function Convert-HtmlToText {
    param([string]$Value)
    if (-not $Value) { return "" }
    $text = $Value -replace '<br\s*/?>', "`n" -replace '</?(div|p|li|ul|ol)[^>]*>', "`n"
    $text = $text -replace '<[^>]+>', ''
    $text = [System.Net.WebUtility]::HtmlDecode($text)
    $text = $text -replace "`r", ''
    $text = $text -replace "`n\s*`n+", "`n`n"
    return $text.Trim()
}

function Get-NormalizedIdentity {
    param($Value)
    if ($null -eq $Value) { return $null }
    if ($Value -is [string]) {
        return [pscustomobject]@{ displayName = $Value; uniqueName = $Value }
    }
    return [pscustomobject]@{ displayName = $Value.displayName; uniqueName = $Value.uniqueName }
}

function Get-ParentIdFromRelations {
    param($RelationData)
    if ($null -eq $RelationData.relations) { return $null }
    foreach ($relation in $RelationData.relations) {
        if ($relation.rel -eq 'System.LinkTypes.Hierarchy-Reverse' -or $relation.attributes.name -eq 'Parent') {
            if ($relation.url -match '/workItems/(\d+)$') { return [int]$Matches[1] }
        }
    }
    return $null
}

function Get-NormalizedComments {
    param($CommentData)
    $items = @()
    foreach ($comment in ($CommentData.comments | ForEach-Object { $_ })) {
        $items += [pscustomobject]@{
            id = if ($comment.id) { $comment.id } else { $comment.commentId }
            text = Convert-HtmlToText $comment.text
            createdDate = $comment.createdDate
            modifiedDate = $comment.modifiedDate
            createdBy = Get-NormalizedIdentity $comment.createdBy
        }
    }
    return $items
}

$chain = New-Object System.Collections.Generic.List[object]
$visited = New-Object System.Collections.Generic.HashSet[int]
$currentId = $WorkItemId
$depth = 0

while ($currentId -and -not $visited.Contains($currentId) -and $depth -lt $MaxParentDepth) {
    [void]$visited.Add($currentId)

    $itemUrl = "$orgUrl/$encodedProject/_apis/wit/workitems/$currentId`?`$expand=relations&api-version=7.1"
    $commentsUrl = "$orgUrl/$encodedProject/_apis/wit/workItems/$currentId/comments`?`$top=200&order=asc&api-version=7.1-preview.4"

    $item = Invoke-AdoRestJson -Uri $itemUrl -Pat $patConfig.Pat
    $relation = $item
    $comments = Invoke-AdoRestJson -Uri $commentsUrl -Pat $patConfig.Pat

    $fieldsData = $item.fields
    $parentId = Get-ParentIdFromRelations $relation

    $chain.Add([pscustomobject]@{
        id = $item.id
        url = $item.url
        type = $fieldsData.'System.WorkItemType'
        title = $fieldsData.'System.Title'
        state = $fieldsData.'System.State'
        reason = $fieldsData.'System.Reason'
        priority = $fieldsData.'Microsoft.VSTS.Common.Priority'
        valueArea = $fieldsData.'Microsoft.VSTS.Common.ValueArea'
        businessValue = $fieldsData.'Microsoft.VSTS.Common.BusinessValue'
        areaPath = $fieldsData.'System.AreaPath'
        iterationPath = $fieldsData.'System.IterationPath'
        assignedTo = Get-NormalizedIdentity $fieldsData.'System.AssignedTo'
        createdBy = Get-NormalizedIdentity $fieldsData.'System.CreatedBy'
        createdDate = $fieldsData.'System.CreatedDate'
        changedDate = $fieldsData.'System.ChangedDate'
        tags = $fieldsData.'System.Tags'
        description = Convert-HtmlToText $fieldsData.'System.Description'
        acceptanceCriteria = Convert-HtmlToText $fieldsData.'Microsoft.VSTS.Common.AcceptanceCriteria'
        reproSteps = Convert-HtmlToText $fieldsData.'Microsoft.VSTS.TCM.ReproSteps'
        commentCount = $fieldsData.'System.CommentCount'
        parentId = $parentId
        comments = Get-NormalizedComments $comments
    })

    $currentId = $parentId
    $depth += 1
}

$topDown = @($chain.ToArray())
[array]::Reverse($topDown)
$markdownSections = foreach ($item in $topDown) {
    $parts = New-Object System.Collections.Generic.List[string]
    $parts.Add("## $($item.type): $($item.title) (#$($item.id))")

    if (-not [string]::IsNullOrWhiteSpace($item.description)) {
        $parts.Add("### Description")
        $parts.Add($item.description)
        $parts.Add("")
    }

    if (-not [string]::IsNullOrWhiteSpace($item.acceptanceCriteria)) {
        $parts.Add("### Acceptance Criteria")
        $parts.Add($item.acceptanceCriteria)
        $parts.Add("")
    }

    if ($item.comments.Count -gt 0) {
        $parts.Add("### Comments")
        ($item.comments | ForEach-Object {
            $author = if ($_.createdBy.displayName) { $_.createdBy.displayName } else { 'Unknown' }
            $date = if ($_.createdDate) { $_.createdDate } else { 'Unknown date' }
            $parts.Add("- $author ($date): $($_.text)")
        }) > $null
    }

    ($parts -join "`n").Trim()
}

[ordered]@{
    context = $context
    workItemId = $WorkItemId
    organization = $orgUrl
    project = $Project
    defaultsConfigured = $false
    retrieval = [ordered]@{
        method = 'Azure DevOps REST API'
        workItemEndpoint = '/_apis/wit/workitems/{id}?$expand=relations&api-version=7.1'
        commentsEndpoint = '/_apis/wit/workItems/{id}/comments?api-version=7.1-preview.4'
        patFile = '%USERPROFILE%\.config\linksoft-skills\azure-devops.env'
    }
    wiql = $wiql
    hierarchy = $topDown
    structuredMarkdown = ($markdownSections -join "`n`n").Trim()
} | ConvertTo-Json -Depth 14

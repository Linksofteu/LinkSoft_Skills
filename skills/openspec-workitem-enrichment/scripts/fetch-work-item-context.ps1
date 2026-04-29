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

if (-not (Get-Command az -ErrorAction SilentlyContinue)) {
    throw "Azure CLI is required."
}

try {
    az account show | Out-Null
} catch {
    throw "Azure CLI is not authenticated. Run 'az login' first."
}

try {
    az boards -h | Out-Null
} catch {
    throw "Azure DevOps CLI extension is not available. Run 'az extension add --name azure-devops' first."
}

function Invoke-AzJson {
    param(
        [Parameter(Mandatory = $true)]
        [string[]]$Arguments
    )

    $output = & az @Arguments 2>&1
    if ($LASTEXITCODE -ne 0) {
        throw (($output | Out-String).Trim())
    }
    return ($output | Out-String | ConvertFrom-Json)
}

$scriptDir = Split-Path -Parent $MyInvocation.MyCommand.Path

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

$orgUrl = if ($context.collectionUri) { $context.collectionUri } else { "https://dev.azure.com/$Org" }

az devops configure --defaults organization="$orgUrl" project="$Project" | Out-Null

$wiql = "SELECT [System.Id], [System.Title], [System.State] FROM WorkItems WHERE [System.Id] = $WorkItemId ORDER BY [System.ChangedDate] DESC"
$fields = "System.Id,System.Title,System.WorkItemType,System.State,System.Reason,System.Description,Microsoft.VSTS.Common.AcceptanceCriteria,Microsoft.VSTS.TCM.ReproSteps,System.AssignedTo,System.CreatedBy,System.AreaPath,System.IterationPath,System.Tags,System.ChangedDate,System.CreatedDate,System.CommentCount,Microsoft.VSTS.Common.Priority,Microsoft.VSTS.Common.ValueArea,Microsoft.VSTS.Common.BusinessValue"

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
            id = $comment.id
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

    $item = Invoke-AzJson -Arguments @('boards','work-item','show','--id',"$currentId",'--org',"$orgUrl",'--fields',"$fields",'--expand','none','--output','json')
    $relation = Invoke-AzJson -Arguments @('boards','work-item','relation','show','--id',"$currentId",'--org',"$orgUrl",'--output','json')
    $comments = Invoke-AzJson -Arguments @('devops','invoke','--organization',"$orgUrl",'--area','wit','--resource','comments','--route-parameters',"project=$Project","workItemId=$currentId",'--api-version','7.1-preview','--output','json')

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
    defaultsConfigured = $true
    wiql = Invoke-AzJson -Arguments @('boards','query','--wiql',"$wiql",'--org',"$orgUrl",'--project',"$Project",'--output','json')
    hierarchy = $topDown
    structuredMarkdown = ($markdownSections -join "`n`n").Trim()
} | ConvertTo-Json -Depth 14

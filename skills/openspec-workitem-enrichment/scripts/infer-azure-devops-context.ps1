param(
    [string]$RepoRoot = (Get-Location).Path,
    [string]$RemoteName = "origin",
    [string]$RemoteUrl
)

if ($args -contains "--help" -or $args -contains "-h") {
    Write-Output @"
Infer Azure DevOps org, project, and repo from a git remote.

Usage:
  infer-azure-devops-context.ps1 [-RepoRoot PATH] [-RemoteName origin] [-RemoteUrl URL]

Output:
  JSON with org, project, repo, remoteName, remoteUrl, and collectionUri.
"@
    exit 0
}

if (-not $RemoteUrl) {
    $RemoteUrl = git -C $RepoRoot config --get "remote.$RemoteName.url"
    if (-not $RemoteUrl) {
        throw "Could not read git remote '$RemoteName' from $RepoRoot"
    }
}

$patterns = @(
    '^https://dev\.azure\.com/(?<org>[^/]+)/(?<project>[^/]+)/_git/(?<repo>[^/]+?)(?:\.git)?/?$',
    '^https://[^@]+@dev\.azure\.com/(?<org>[^/]+)/(?<project>[^/]+)/_git/(?<repo>[^/]+?)(?:\.git)?/?$',
    '^git@ssh\.dev\.azure\.com:v3/(?<org>[^/]+)/(?<project>[^/]+)/(?<repo>[^/]+?)(?:\.git)?$',
    '^ssh://git@ssh\.dev\.azure\.com/v3/(?<org>[^/]+)/(?<project>[^/]+)/(?<repo>[^/]+?)(?:\.git)?/?$',
    '^https://(?<org>[^./]+)\.visualstudio\.com/(?<project>[^/]+)/_git/(?<repo>[^/]+?)(?:\.git)?/?$'
)

$matchResult = $null
foreach ($pattern in $patterns) {
    if ($RemoteUrl -match $pattern) {
        $matchResult = [pscustomobject]@{
            Org = $Matches.org
            Project = $Matches.project
            Repo = $Matches.repo
        }
        break
    }
}

if (-not $matchResult) {
    throw "Could not infer Azure DevOps org/project from remote URL: $RemoteUrl"
}

$repo = $matchResult.Repo -replace '\.git$',''
$collectionUri = if ($RemoteUrl -match '\.visualstudio\.com/') {
    "https://$($matchResult.Org).visualstudio.com"
} else {
    "https://dev.azure.com/$($matchResult.Org)"
}

[pscustomobject]@{
    org = $matchResult.Org
    project = $matchResult.Project
    repo = $repo
    remoteName = $RemoteName
    remoteUrl = $RemoteUrl
    collectionUri = $collectionUri
    projectUri = "$collectionUri/$($matchResult.Project)"
} | ConvertTo-Json -Depth 4

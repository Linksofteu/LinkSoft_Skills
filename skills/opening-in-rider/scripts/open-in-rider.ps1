#!/usr/bin/env pwsh
Set-StrictMode -Version Latest
$ErrorActionPreference = 'Stop'

function Fail {
    param(
        [Parameter(Mandatory = $true)][string]$Message,
        [Parameter(Mandatory = $false)][int]$Code = 2
    )

    [Console]::Error.WriteLine($Message)
    exit $Code
}

function Show-Usage {
    @'
Usage: open-in-rider.ps1 [path] [--line N]

Open a file or folder in JetBrains Rider.
If possible, open it within the nearest .sln context.

Arguments:
  path         File or directory to open (default: .)
  --line, -l   Line number when opening a file
  --help, -h   Show this help
'@
}

function Get-BestMatch {
    param(
        [Parameter(Mandatory = $true)][string]$DirectoryName,
        [Parameter(Mandatory = $true)][string[]]$Candidates
    )

    foreach ($candidate in $Candidates) {
        $base = [System.IO.Path]::GetFileNameWithoutExtension($candidate)
        if ($base -eq $DirectoryName) {
            return $candidate
        }
    }

    return ($Candidates | Sort-Object | Select-Object -First 1)
}

function Find-NearestProjectFile {
    param(
        [Parameter(Mandatory = $true)][string]$StartDirectory,
        [Parameter(Mandatory = $true)][ValidateSet('sln', 'csproj')][string]$Extension
    )

    $dir = (Resolve-Path -LiteralPath $StartDirectory).Path
    while ($true) {
        $matches = @(Get-ChildItem -LiteralPath $dir -Filter "*.$Extension" -File -ErrorAction SilentlyContinue | Select-Object -ExpandProperty FullName)
        if ($matches.Count -gt 0) {
            $dirName = Split-Path -Leaf $dir
            return Get-BestMatch -DirectoryName $dirName -Candidates $matches
        }

        $parent = [System.IO.Directory]::GetParent($dir)
        if ($null -eq $parent) {
            break
        }
        $dir = $parent.FullName
    }

    return $null
}

function Get-RiderCommand {
    foreach ($candidate in @('rider', 'rider.bat', 'rider64.exe')) {
        if (Get-Command $candidate -ErrorAction SilentlyContinue) {
            return $candidate
        }
    }

    return $null
}

function Start-RiderDetached {
    param(
        [Parameter(Mandatory = $true)][string]$FilePath,
        [Parameter(Mandatory = $true)][string[]]$Arguments
    )

    Start-Process -FilePath $FilePath -ArgumentList $Arguments | Out-Null
    exit 0
}

$target = '.'
$targetProvided = $false
$line = $null

for ($i = 0; $i -lt $args.Count; $i++) {
    switch ($args[$i]) {
        '-h' { Show-Usage; exit 0 }
        '--help' { Show-Usage; exit 0 }
        '-l' {
            if ($i + 1 -ge $args.Count) {
                Fail 'Error: missing value for --line' 2
            }
            $i++
            if ($args[$i] -notmatch '^[1-9][0-9]*$') {
                Fail 'Error: --line must be a positive integer' 2
            }
            $line = [int]$args[$i]
        }
        '--line' {
            if ($i + 1 -ge $args.Count) {
                Fail 'Error: missing value for --line' 2
            }
            $i++
            if ($args[$i] -notmatch '^[1-9][0-9]*$') {
                Fail 'Error: --line must be a positive integer' 2
            }
            $line = [int]$args[$i]
        }
        default {
            if ($targetProvided) {
                Fail 'Error: only one path argument is supported' 2
            }
            $target = $args[$i]
            $targetProvided = $true
        }
    }
}

$rider = Get-RiderCommand
if (-not $rider) {
    Fail 'Error: Rider CLI not found on PATH. Expected one of: rider, rider.bat, rider64.exe' 127
}

if (-not (Test-Path -LiteralPath $target)) {
    Fail "Error: path does not exist: $target" 2
}

$target = (Resolve-Path -LiteralPath $target).Path

if (Test-Path -LiteralPath $target -PathType Container) {
    $openMode = 'dir'
    $searchDir = $target
}
else {
    $openMode = 'file'
    $searchDir = Split-Path -Parent $target
}

$solution = Find-NearestProjectFile -StartDirectory $searchDir -Extension sln
$project = $null
if (-not $solution) {
    $project = Find-NearestProjectFile -StartDirectory $searchDir -Extension csproj
}

if ($solution) {
    if ($openMode -eq 'file') {
        if ($line) {
            Start-RiderDetached -FilePath $rider -Arguments @($solution, '--line', "$line", $target)
        }
        Start-RiderDetached -FilePath $rider -Arguments @($solution, $target)
    }

    Start-RiderDetached -FilePath $rider -Arguments @($solution)
}

if ($project) {
    if ($openMode -eq 'file') {
        if ($line) {
            Start-RiderDetached -FilePath $rider -Arguments @($project, '--line', "$line", $target)
        }
        Start-RiderDetached -FilePath $rider -Arguments @($project, $target)
    }

    Start-RiderDetached -FilePath $rider -Arguments @($project)
}

if ($openMode -eq 'file' -and $line) {
    Start-RiderDetached -FilePath $rider -Arguments @('--line', "$line", $target)
}

Start-RiderDetached -FilePath $rider -Arguments @($target)

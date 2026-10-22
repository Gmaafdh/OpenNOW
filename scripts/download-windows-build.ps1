<#
.SYNOPSIS
  Downloads the unsigned Windows x64 OpenNOW test build from GitHub Actions
  without going through a browser.

.DESCRIPTION
  Chrome, Edge and Windows Defender block this build when it is downloaded in a
  browser. That is expected: the package is unsigned and it is served from
  GitHub's artifact storage, so Safe Browsing treats it as a "rare, dangerous
  file". The bytes themselves are the ones the CI run produced.

  This script fetches the artifact with the GitHub CLI (no browser, so no Safe
  Browsing download block), verifies every file against the SHA256SUMS the build
  wrote, clears the Zone.Identifier mark that SmartScreen uses, and extracts the
  portable ZIP so OpenNOW.exe can be launched immediately.

.PARAMETER RunId
  Specific workflow run id. Defaults to the newest Windows executable run on the
  configured branch.

.PARAMETER Destination
  Where the artifact is unpacked. Defaults to Downloads\OpenNOW-windows.

.PARAMETER Repository
  owner/repo that runs the workflow. Defaults to Gmaafdh/OpenNOW.

.PARAMETER Branch
  Branch whose newest run is downloaded when -RunId is omitted.

.EXAMPLE
  # One-time setup, then the newest build
  winget install --id GitHub.cli
  gh auth login
  .\scripts\download-windows-build.ps1

.EXAMPLE
  .\scripts\download-windows-build.ps1 -RunId 39767379490
#>
[CmdletBinding()]
param(
    [string]$RunId = "",
    [string]$Repository = "Gmaafdh/OpenNOW",
    [string]$Branch = "arena/857f597a-opennow",
    [string]$Workflow = "arena-windows-exe.yml",
    [string]$Artifact = "OpenNOW-Windows-x64-dx10",
    [string]$Destination = (Join-Path $env:USERPROFILE "Downloads\OpenNOW-windows")
)

$ErrorActionPreference = "Stop"

function Write-Step {
    param([string]$Message)
    Write-Host "==> $Message" -ForegroundColor Cyan
}

if (-not (Get-Command gh -ErrorAction SilentlyContinue)) {
    throw @"
GitHub CLI (gh) is required so the download skips the browser.
Install it, sign in once, then rerun this script:

  winget install --id GitHub.cli
  gh auth login
"@
}

if (-not $RunId) {
    Write-Step "Looking up the newest Windows executable run on $Branch"
    $runs = gh run list --repo $Repository --workflow $Workflow --branch $Branch --limit 1 `
        --json databaseId,headSha,status,conclusion,createdAt | ConvertFrom-Json
    if (-not $runs -or $runs.Count -eq 0) {
        throw "No Windows executable run found for $Branch. Start one with: gh workflow run $Workflow --repo $Repository --ref $Branch"
    }
    $RunId = [string]$runs[0].databaseId
    Write-Host ("    run {0} · commit {1} · {2}" -f $RunId, $runs[0].headSha.Substring(0, 7), $runs[0].conclusion)
    if ($runs[0].conclusion -and $runs[0].conclusion -ne "success") {
        throw "The newest run ($RunId) ended as '$($runs[0].conclusion)'. Pass -RunId of a successful run instead."
    }
}

if (Test-Path -LiteralPath $Destination) {
    Write-Step "Clearing previous download in $Destination"
    Remove-Item -LiteralPath $Destination -Recurse -Force
}
New-Item -ItemType Directory -Path $Destination -Force | Out-Null

Write-Step "Downloading $Artifact from run $RunId"
gh run download $RunId --repo $Repository --name $Artifact --dir $Destination
if ($LASTEXITCODE -ne 0) { throw "gh run download failed with exit code $LASTEXITCODE" }

$manifest = Join-Path $Destination "SHA256SUMS"
if (-not (Test-Path -LiteralPath $manifest)) { throw "SHA256SUMS is missing from the artifact" }

Write-Step "Verifying package hashes"
$verified = 0
foreach ($line in Get-Content -LiteralPath $manifest) {
    if (-not $line.Trim()) { continue }
    $parts = $line.Trim() -split '\s+', 2
    if ($parts.Count -ne 2) { continue }
    $expected = $parts[0].ToLowerInvariant()
    $name = $parts[1].TrimStart('*')
    $path = Join-Path $Destination $name
    if (-not (Test-Path -LiteralPath $path)) { throw "Listed package is missing: $name" }
    $actual = (Get-FileHash -LiteralPath $path -Algorithm SHA256).Hash.ToLowerInvariant()
    if ($actual -ne $expected) { throw "Hash mismatch for $name`nexpected $expected`nactual   $actual" }
    Write-Host ("    {0} ok" -f $name) -ForegroundColor Green
    $verified++
}
if ($verified -eq 0) { throw "SHA256SUMS did not list any package" }

Write-Step "Removing the browser/SmartScreen mark of the web"
Get-ChildItem -LiteralPath $Destination -File | Unblock-File

$zip = Get-ChildItem -LiteralPath $Destination -Filter *.zip | Select-Object -First 1
if (-not $zip) { throw "The portable ZIP is missing from the artifact" }

$portable = Join-Path $Destination "portable"
Write-Step "Extracting $($zip.Name)"
Expand-Archive -LiteralPath $zip.FullName -DestinationPath $portable -Force
Get-ChildItem -LiteralPath $portable -Recurse -File | Unblock-File

$exe = Get-ChildItem -LiteralPath $portable -Filter OpenNOW.exe -Recurse | Select-Object -First 1
if (-not $exe) { throw "OpenNOW.exe is missing from the extracted ZIP" }

Write-Host ""
Write-Host "Ready." -ForegroundColor Green
Write-Host "  Portable exe : $($exe.FullName)"
$setup = Get-ChildItem -LiteralPath $Destination -Filter *-setup.exe | Select-Object -First 1
if ($setup) { Write-Host "  Installer    : $($setup.FullName)" }
Write-Host "  Build info   : $(Join-Path $Destination 'BUILD-INFO.txt')"
Write-Host ""
Write-Host "This build is unsigned, so Windows may still show a SmartScreen prompt"
Write-Host "on the first launch: choose More info, then Run anyway."

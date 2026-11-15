# build.ps1 - Creates dist/<target>/EliteMobVisuals and a zip per target, ready
# for CurseForge.
#
# Usage:
#   ./scripts/build/build.ps1                 # tests, then build
#   ./scripts/build/build.ps1 -SkipChecks     # build without the tests
#   ./scripts/build/build.ps1 -Bump patch     # 0.1.0 -> 0.1.1, then build
#   ./scripts/build/build.ps1 -Bump minor     # 0.1.0 -> 0.2.0, then build
#   ./scripts/build/build.ps1 -Bump major     # 0.1.0 -> 1.0.0, then build
#
# The package holds only what the game loads: the TOC, LICENSE, NOTICE, and the
# Core, Locales, UI and media folders. Docs, tools, scripts and the reference
# images stay behind.

param(
    [ValidateSet("major", "minor", "patch")]
    [string]$Bump,
    [switch]$SkipChecks
)

$ErrorActionPreference = "Stop"

$AddonName = "EliteMobVisuals"
$root = Split-Path (Split-Path $PSScriptRoot -Parent) -Parent
$tocFile = Join-Path $root "$AddonName.toc"

# Build targets: the one place that lists interface numbers. Add Retail here
# (Interface 120105, label "Midnight (live)") if the addon ever ships there.
$Targets = @(
    @{ Name = 'forever'; Interface = '16001'; Label = 'WoW Forever' }   # 1.60.1
)

# What ships. Everything else in the repo is development-only.
$PackageFiles = @("$AddonName.toc", "LICENSE", "NOTICE")
$PackageDirs = @("Core", "Locales", "UI", "media")

# --- Checks (skip with -SkipChecks) ---
if (-not $SkipChecks) {
    Write-Host ""
    Write-Host "Checks:" -ForegroundColor Cyan
    $testsDir = Join-Path $root "tools\tests"
    if (-not (Get-Command node -ErrorAction SilentlyContinue)) {
        throw "Node.js is needed to run the tests (tools/tests). Install it, or build with -SkipChecks."
    }
    if (-not (Test-Path (Join-Path $testsDir "node_modules\fengari"))) {
        throw "The tests' Lua VM is not installed. Run: cd tools/tests; npm install  (or build with -SkipChecks)."
    }
    Write-Host "  tests (tools/tests)" -ForegroundColor Gray
    $out = & node (Join-Path $testsDir "run-all.js") 2>&1
    if ($LASTEXITCODE -ne 0) {
        $out | ForEach-Object { Write-Host "    $_" }
        throw "Tests failed. Fix them, or build with -SkipChecks if you know why."
    }
    Write-Host "    $($out | Select-Object -Last 1)" -ForegroundColor Gray
}

# --- Version bump ---
if ($Bump) {
    $tocContent = Get-Content $tocFile -Raw -Encoding UTF8
    if ($tocContent -match '## Version:\s*(\d+)\.(\d+)\.(\d+)') {
        $major = [int]$Matches[1]; $minor = [int]$Matches[2]; $patch = [int]$Matches[3]
    } else {
        throw "Could not parse version from $AddonName.toc"
    }
    $old = "$major.$minor.$patch"
    switch ($Bump) {
        "major" { $major++; $minor = 0; $patch = 0 }
        "minor" { $minor++; $patch = 0 }
        "patch" { $patch++ }
    }
    $new = "$major.$minor.$patch"
    $tocContent = $tocContent -replace "## Version:\s*$([regex]::Escape($old))", "## Version: $new"
    [IO.File]::WriteAllText($tocFile, $tocContent, (New-Object System.Text.UTF8Encoding $false))
    Write-Host "Version bumped: $old -> $new" -ForegroundColor Cyan
}

# --- Build ---
$distDir = Join-Path $root "dist"
if (Test-Path $distDir) {
    Remove-Item $distDir -Recurse -Force
}

$tocContent = Get-Content $tocFile -Raw -Encoding UTF8
$version = if ($tocContent -match '## Version:\s*(\d+\.\d+\.\d+)') { $Matches[1] } else { "unknown" }

function Build-Variant {
    param([hashtable]$Target)

    $addonDir = Join-Path (Join-Path $distDir $Target.Name) $AddonName
    New-Item -ItemType Directory -Path $addonDir -Force | Out-Null

    foreach ($f in $PackageFiles) { Copy-Item (Join-Path $root $f) -Destination $addonDir }
    foreach ($d in $PackageDirs) { Copy-Item (Join-Path $root $d) -Destination (Join-Path $addonDir $d) -Recurse }

    # The target's interface line. The TOC holds a non-ASCII author name, so
    # read and write it as UTF-8 without a BOM.
    $tocPath = Join-Path $addonDir "$AddonName.toc"
    $content = [IO.File]::ReadAllText($tocPath)
    $content = $content -replace '(?m)^## Interface:[^\r\n]*', "## Interface: $($Target.Interface)"
    [IO.File]::WriteAllText($tocPath, $content, (New-Object System.Text.UTF8Encoding $false))

    # Every file the TOC lists must be in the package, or the client skips it.
    $missing = @()
    foreach ($line in ($content -split "`r?`n")) {
        if ($line -match '^\s*(?!#)([^\s\[]+\.(?:lua|xml))') {
            if (-not (Test-Path (Join-Path $addonDir $Matches[1]))) { $missing += $Matches[1] }
        }
    }
    if ($missing.Count -gt 0) {
        throw "Package '$($Target.Name)' is missing TOC-listed files: $($missing -join ', ')"
    }

    # Every addon texture a Lua file names must ship.
    $luaText = (Get-ChildItem $addonDir -Recurse -File -Include '*.lua' | ForEach-Object { [IO.File]::ReadAllText($_.FullName) }) -join "`n"
    $missingTex = @()
    foreach ($m in [regex]::Matches($luaText, 'TEX \.\. "([^"]+)"')) {
        $p = Join-Path $addonDir ("media\textures\" + $m.Groups[1].Value + ".tga")
        if (-not (Test-Path $p)) { $missingTex += $m.Groups[1].Value }
    }
    if ($missingTex.Count -gt 0) {
        throw "Package '$($Target.Name)' is missing textures: $($missingTex -join ', '). Run: python tools/art/build-art.py"
    }

    $zipName = "$AddonName-$version-$($Target.Name).zip"
    $zipPath = Join-Path $distDir $zipName
    Compress-Archive -Path $addonDir -DestinationPath $zipPath -Force

    $kb = [math]::Round((Get-Item $zipPath).Length / 1KB)
    $count = (Get-ChildItem $addonDir -Recurse -File).Count
    Write-Host ("  {0,-38} Interface {1,-7} {2,5} KB, {3} files" -f $zipName, $Target.Interface, $kb, $count) -ForegroundColor White
}

Write-Host ""
Write-Host "Building Elite Mob Visuals v$version..." -ForegroundColor Cyan
Write-Host ""
Write-Host "Zips:" -ForegroundColor Green
foreach ($target in $Targets) { Build-Variant -Target $target }

# Release notes: the version's section is the CurseForge changelog.
$notesFile = Join-Path $root "RELEASE_NOTES.md"
$hasNotes = (Test-Path $notesFile) -and ((Get-Content $notesFile -Raw -Encoding UTF8) -match "(?m)^## $([regex]::Escape($version))\b")
Write-Host ""
if ($hasNotes) {
    Write-Host "Changelog: paste the '## $version' section of RELEASE_NOTES.md" -ForegroundColor Gray
} else {
    Write-Warning "RELEASE_NOTES.md has no '## $version' section. Add one before uploading."
}

Write-Host ""
Write-Host "Ready to upload to CurseForge:" -ForegroundColor Green
foreach ($target in $Targets) {
    Write-Host ("  {0,-42} -> {1}" -f "dist/$AddonName-$version-$($target.Name).zip", $target.Label) -ForegroundColor White
}

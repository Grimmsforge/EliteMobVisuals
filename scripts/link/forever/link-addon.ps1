# link-addon.ps1 - Create a junction from the WoW Forever AddOns folder to this repo.
# The repo is a working addon as it stands, so /reload in game picks up edits.
# To test the packaged build instead, use scripts/link/dist-forever/link-forever.ps1.

$addonsPath = "A:\Blizzard\World of Warcraft\_forever_\Interface\AddOns"
$linkPath = Join-Path $addonsPath "EliteMobVisuals"
$repoPath = Split-Path (Split-Path (Split-Path $PSScriptRoot -Parent) -Parent) -Parent

if (-not (Test-Path $addonsPath)) {
    Write-Host "ERROR: AddOns folder not found: $addonsPath" -ForegroundColor Red
    exit 1
}

if (Test-Path $linkPath) {
    $item = Get-Item $linkPath -Force
    if ($item.Attributes -band [System.IO.FileAttributes]::ReparsePoint) {
        $existingTarget = @($item.Target)[0]
        if ($existingTarget -eq $repoPath) {
            Write-Host "Junction already points to the repo: $linkPath" -ForegroundColor Yellow
            exit 0
        }
        Write-Host "Replacing existing junction: $linkPath -> $existingTarget" -ForegroundColor Yellow
        Remove-Item $linkPath -Force
    } else {
        Write-Host "WARNING: $linkPath exists and is not a junction. Remove it manually first." -ForegroundColor Red
        exit 1
    }
}

New-Item -ItemType Junction -Path $linkPath -Target $repoPath | Out-Null
Write-Host "Junction created: $linkPath -> $repoPath" -ForegroundColor Green

# link-forever.ps1 - Link the dist/forever build into the WoW Forever AddOns folder.
# Use this to test the packaged distribution before uploading.
# Run scripts/build/build.ps1 first to generate dist/forever/EliteMobVisuals.

$addonsPath = "A:\Blizzard\World of Warcraft\_forever_\Interface\AddOns"
$linkPath = Join-Path $addonsPath "EliteMobVisuals"
$root = Split-Path (Split-Path (Split-Path $PSScriptRoot -Parent) -Parent) -Parent
$targetPath = Join-Path $root "dist\forever\EliteMobVisuals"

if (-not (Test-Path $targetPath)) {
    Write-Host "ERROR: dist/forever/EliteMobVisuals does not exist. Run scripts/build/build.ps1 first." -ForegroundColor Red
    exit 1
}

if (Test-Path $linkPath) {
    $item = Get-Item $linkPath -Force
    if ($item.Attributes -band [System.IO.FileAttributes]::ReparsePoint) {
        $existingTarget = @($item.Target)[0]
        if ($existingTarget -eq $targetPath) {
            Write-Host "Junction already points to the forever dist: $linkPath" -ForegroundColor Yellow
            exit 0
        }
        Write-Host "Replacing existing junction: $linkPath -> $existingTarget" -ForegroundColor Yellow
        Remove-Item $linkPath -Force
    } else {
        Write-Host "WARNING: $linkPath exists and is not a junction. Remove it manually first." -ForegroundColor Red
        exit 1
    }
}

New-Item -ItemType Junction -Path $linkPath -Target $targetPath | Out-Null
Write-Host "Junction created: $linkPath -> $targetPath" -ForegroundColor Green
Write-Host "You are now testing the FOREVER distribution package." -ForegroundColor Cyan
Write-Host "Run scripts/link/forever/link-addon.ps1 to go back to the repo." -ForegroundColor Cyan

# unlink-addon.ps1 - Remove the repo junction from the WoW Forever AddOns folder.
# This does NOT delete your repo files, only the junction.

$addonsPath = "A:\Blizzard\World of Warcraft\_forever_\Interface\AddOns"
$linkPath = Join-Path $addonsPath "EliteMobVisuals"

if (-not (Test-Path $linkPath)) {
    Write-Host "Nothing to remove: $linkPath does not exist." -ForegroundColor Yellow
    exit 0
}

$item = Get-Item $linkPath -Force
if ($item.Attributes -band [System.IO.FileAttributes]::ReparsePoint) {
    Remove-Item $linkPath -Force
    Write-Host "Junction removed: $linkPath" -ForegroundColor Green
} else {
    Write-Host "WARNING: $linkPath is not a junction. Skipping to avoid data loss." -ForegroundColor Red
    exit 1
}

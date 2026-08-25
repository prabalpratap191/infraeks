# PowerShell Script to Verify .gitignore is Working
# This script checks if excluded folders will be pushed to Git

Write-Host "`n======================================" -ForegroundColor Cyan
Write-Host "  .gitignore Verification Tool" -ForegroundColor Cyan
Write-Host "======================================`n" -ForegroundColor Cyan

# Function to check if folder exists
function Test-Folder {
    param($folderName)
    if (Test-Path $folderName) {
        Write-Host "✓ Found: $folderName" -ForegroundColor Yellow
        return $true
    } else {
        Write-Host "  (Not present: $folderName)" -ForegroundColor DarkGray
        return $false
    }
}

# Check if Git is initialized
if (-not (Test-Path ".git")) {
    Write-Host "✗ Git not initialized. Run 'git init' first.`n" -ForegroundColor Red
    exit 1
}

Write-Host "Folders to be excluded from Git:" -ForegroundColor Cyan
Write-Host "--------------------------------`n" -ForegroundColor Cyan

# List of folders that should be ignored
$foldersToIgnore = @(
    ".slingshot",
    ".agent",
    ".agents",
    "target",
    "C:\Users\prasingh80"
)

$foundFolders = @()
foreach ($folder in $foldersToIgnore) {
    if (Test-Folder $folder) {
        $foundFolders += $folder
    }
}

if ($foundFolders.Count -eq 0) {
    Write-Host "`nNo excluded folders found in current directory." -ForegroundColor Green
    Write-Host "This is normal if you're running this for the first time.`n" -ForegroundColor Green
} else {
    Write-Host ""
}

# Check if .gitignore exists
Write-Host "`nChecking .gitignore file..." -ForegroundColor Cyan
Write-Host "---------------------------`n" -ForegroundColor Cyan

if (Test-Path ".gitignore") {
    Write-Host "✓ .gitignore exists" -ForegroundColor Green
    
    # Check if patterns are in .gitignore
    $gitignoreContent = Get-Content ".gitignore" -Raw
    
    Write-Host "`nVerifying patterns in .gitignore:" -ForegroundColor Cyan
    foreach ($folder in $foldersToIgnore) {
        if ($gitignoreContent -match [regex]::Escape($folder)) {
            Write-Host "  ✓ $folder/ is in .gitignore" -ForegroundColor Green
        } else {
            Write-Host "  ✗ $folder/ NOT in .gitignore" -ForegroundColor Red
        }
    }
} else {
    Write-Host "✗ .gitignore does NOT exist!" -ForegroundColor Red
    Write-Host "  Create it before proceeding.`n" -ForegroundColor Yellow
    exit 1
}

# Check Git status
Write-Host "`n`nChecking Git status..." -ForegroundColor Cyan
Write-Host "----------------------`n" -ForegroundColor Cyan

# Get untracked files
$untrackedFiles = git ls-files --others --exclude-standard

# Check if any ignored folders appear in untracked files
$problemFound = $false
foreach ($folder in $foundFolders) {
    if ($untrackedFiles -match [regex]::Escape($folder)) {
        Write-Host "✗ WARNING: $folder/ appears in Git tracking!" -ForegroundColor Red
        $problemFound = $true
    } else {
        Write-Host "✓ $folder/ is properly ignored" -ForegroundColor Green
    }
}

# Show ignored files
Write-Host "`n`nListing all ignored items..." -ForegroundColor Cyan
Write-Host "----------------------------`n" -ForegroundColor Cyan

$ignoredItems = git status --ignored --short | Select-String "^!!"
if ($ignoredItems) {
    $ignoredItems | ForEach-Object {
        $item = $_ -replace "^!! ", ""
        Write-Host "  Ignored: $item" -ForegroundColor DarkGray
    }
} else {
    Write-Host "  No ignored items found." -ForegroundColor DarkGray
}

# Final summary
Write-Host "`n`n======================================" -ForegroundColor Cyan
if ($problemFound) {
    Write-Host "  STATUS: ISSUES FOUND" -ForegroundColor Red
    Write-Host "======================================`n" -ForegroundColor Cyan
    Write-Host "Action Required:" -ForegroundColor Yellow
    Write-Host "1. Review .gitignore patterns" -ForegroundColor Yellow
    Write-Host "2. Run: git rm -r --cached .slingshot/ .agent/" -ForegroundColor Yellow
    Write-Host "3. Verify again with this script`n" -ForegroundColor Yellow
} else {
    Write-Host "  STATUS: ALL GOOD ✓" -ForegroundColor Green
    Write-Host "======================================`n" -ForegroundColor Cyan
    Write-Host "Excluded folders will NOT be pushed to Git." -ForegroundColor Green
    Write-Host "Safe to proceed with 'git add .' and 'git push'.`n" -ForegroundColor Green
}

# Provide next steps
Write-Host "Next steps:" -ForegroundColor Cyan
Write-Host "1. git add ." -ForegroundColor White
Write-Host "2. git status (verify what will be committed)" -ForegroundColor White
Write-Host "3. git commit -m 'Your message'" -ForegroundColor White
Write-Host "4. git push -u origin main`n" -ForegroundColor White

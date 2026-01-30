# WordPress Original Media Extractor
# This script copies only original media files (not WordPress resized versions) to a destination folder
# Skips duplicate files based on content hash

param(
    [string]$SourceDir = ".",
    [string]$DestDir = "./media"
)

# Create destination folder if it doesn't exist
if (-not (Test-Path $DestDir)) {
    New-Item -ItemType Directory -Path $DestDir -Force | Out-Null
    Write-Host "Created destination folder: $DestDir" -ForegroundColor Green
}

# Get all files recursively
$allFiles = Get-ChildItem -Path $SourceDir -Recurse -File

# Image extensions that WordPress typically resizes
$imageExtensions = @('.jpg', '.jpeg', '.png', '.gif', '.webp', '.bmp')

# All media extensions to include
$mediaExtensions = @('.jpg', '.jpeg', '.png', '.gif', '.webp', '.bmp', '.mp4', '.mov', '.avi', '.mkv', '.webm', '.mp3', '.wav', '.ogg', '.pdf', '.doc', '.docx', '.zip')

# Track copied files by hash to avoid duplicates
$copiedHashes = @{}
# Track destination filenames to handle name collisions for different files
$destFileNames = @{}

$copyCount = 0
$skipCount = 0
$duplicateCount = 0

foreach ($file in $allFiles) {
    $filename = $file.Name
    $ext = $file.Extension.ToLower()
    
    # Skip the script itself and files in destination folder
    if ($file.FullName -eq $PSCommandPath -or $file.FullName -like "*$DestDir*") {
        continue
    }
    
    # Check if this is an image file that might be a resized version
    if ($imageExtensions -contains $ext) {
        # WordPress resized pattern: filename-{width}x{height}.ext
        # Examples: image-150x150.jpg, image-1024x768.jpg
        $pattern = '-\d+x\d+\.[^.]+$'
        
        if ($filename -match $pattern) {
            Write-Host "[SKIP] Resized: $filename" -ForegroundColor DarkGray
            $skipCount++
            continue
        }
    }
    
    # Check if it's a media file we want to copy
    if ($mediaExtensions -contains $ext) {
        # Calculate file hash to check for duplicates
        $fileHash = (Get-FileHash -Path $file.FullName -Algorithm SHA256).Hash
        
        # Skip if this exact file content has already been copied
        if ($copiedHashes.ContainsKey($fileHash)) {
            Write-Host "[SKIP] Duplicate content: $filename (same as $($copiedHashes[$fileHash]))" -ForegroundColor DarkYellow
            $duplicateCount++
            continue
        }
        
        # Determine destination filename
        $destFileName = $filename
        $destPath = Join-Path $DestDir $destFileName
        
        # Handle filename collisions (different content, same name)
        $baseName = $file.BaseName
        $counter = 1
        while ($destFileNames.ContainsKey($destFileName)) {
            $destFileName = "$baseName`_$counter$ext"
            $destPath = Join-Path $DestDir $destFileName
            $counter++
        }
        
        # Copy the file
        Copy-Item $file.FullName $destPath -Force
        $copiedHashes[$fileHash] = $destFileName
        $destFileNames[$destFileName] = $true
        
        Write-Host "[COPY] $filename" -ForegroundColor Green
        $copyCount++
    } else {
        Write-Host "[SKIP] Not media: $filename" -ForegroundColor DarkGray
    }
}

Write-Host "`n==================================" -ForegroundColor Cyan
Write-Host "Done! Summary:" -ForegroundColor Cyan
Write-Host "  Original files copied: $copyCount" -ForegroundColor Green
Write-Host "  Resized files skipped: $skipCount" -ForegroundColor Yellow
Write-Host "  Duplicates skipped: $duplicateCount" -ForegroundColor Yellow
Write-Host "  Total unique files in /media: $($copiedHashes.Count)" -ForegroundColor Cyan
Write-Host "==================================" -ForegroundColor Cyan

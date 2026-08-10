# Move Docker WSL data from C: to D: and create junction

$source = Join-Path $env:LOCALAPPDATA 'Docker\wsl'
$destDrive = 'D:\DockerData'
$dest = Join-Path $destDrive 'wsl'
$backup = "$env:LOCALAPPDATA\Docker\wsl_backup"

Write-Host "Source: $source"
Write-Host "Dest: $dest"

# Verify Docker is stopped
$dockerProc = Get-Process -Name 'Docker Desktop','docker','com.docker.backend','com.docker.build' -ErrorAction SilentlyContinue
if ($dockerProc) {
    Write-Host "ERROR: Docker processes still running. Stopping..."
    Stop-Process -Name 'Docker Desktop' -Force -ErrorAction SilentlyContinue
    Stop-Process -Name docker -Force -ErrorAction SilentlyContinue
    Stop-Process -Name com.docker.backend -Force -ErrorAction SilentlyContinue
    Stop-Process -Name 'com.docker.build' -Force -ErrorAction SilentlyContinue
    Stop-Process -Name 'com.docker.dev-envs' -Force -ErrorAction SilentlyContinue
    Start-Sleep -Seconds 5
}

# Stop WSL
wsl --shutdown
Start-Sleep -Seconds 3

# Check if source exists
if (-not (Test-Path $source)) {
    Write-Host "Source $source does not exist. Nothing to move."
    exit 0
}

# Check if destination already exists
if (Test-Path $dest) {
    Write-Host "Destination $dest already exists. Aborting."
    exit 1
}

# Create destination directory
New-Item -ItemType Directory -Path $destDrive -Force | Out-Null

# Check if source is a junction already
$item = Get-Item $source
if ($item.Attributes -band [System.IO.FileAttributes]::ReparsePoint) {
    Write-Host "Source is already a junction/reparse point. Nothing to do."
    exit 0
}

Write-Host "Moving $source to $dest ..."
Move-Item -Path $source -Destination $dest -Force
Write-Host "Move complete."

Write-Host "Creating junction from $source -> $dest ..."
cmd /c mklink /J "$source" "$dest"
Write-Host "Junction created."

# Verify
Write-Host "`n=== Verification ==="
Get-Item $source | Select-Object FullName, Attributes, LinkType, Target

Write-Host "`n=== Free space on C: ==="
Get-PSDrive C | Select-Object Used, Free

Write-Host "`n=== Free space on D: ==="
Get-PSDrive D | Select-Object Used, Free

Write-Host "`nDone. Docker data moved to D: drive."
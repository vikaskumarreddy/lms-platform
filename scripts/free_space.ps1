# Stop Docker processes
Stop-Process -Name 'Docker Desktop' -Force -ErrorAction SilentlyContinue
Stop-Process -Name docker -Force -ErrorAction SilentlyContinue
Stop-Process -Name com.docker.backend -Force -ErrorAction SilentlyContinue
Stop-Process -Name 'com.docker.build' -Force -ErrorAction SilentlyContinue
Stop-Process -Name 'com.docker.dev-envs' -Force -ErrorAction SilentlyContinue
Start-Sleep -Seconds 3

# Show Docker WSL data size
Write-Host "=== Docker WSL data ==="
$wslPath = Join-Path $env:LOCALAPPDATA 'Docker\wsl'
Get-ChildItem -Path $wslPath -Recurse -ErrorAction SilentlyContinue | Measure-Object -Property Length -Sum | ForEach-Object {
    Write-Host ("Total size: {0:N2} GB" -f ($_.Sum / 1GB))
}

# Show largest temp files
Write-Host "`n=== Temp files ==="
Get-ChildItem -Path $env:TEMP -Recurse -ErrorAction SilentlyContinue | Measure-Object -Property Length -Sum | ForEach-Object {
    Write-Host ("Temp size: {0:N2} GB" -f ($_.Sum / 1GB))
}

# Show npm cache size
Write-Host "`n=== npm cache ==="
$npmCache = Join-Path $env:LOCALAPPDATA 'npm-cache'
if (Test-Path $npmCache) {
    Get-ChildItem -Path $npmCache -Recurse -ErrorAction SilentlyContinue | Measure-Object -Property Length -Sum | ForEach-Object {
        Write-Host ("npm cache size: {0:N2} GB" -f ($_.Sum / 1GB))
    }
} else {
    Write-Host "npm cache not found"
}

# Show WSL distros
Write-Host "`n=== WSL distros ==="
wsl --list --verbose

Write-Host "`nDone"
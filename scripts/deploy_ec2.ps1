<#
.SYNOPSIS
    Automated 1-Click Deployment Script for Axisora Forge LMS on AWS EC2.

.DESCRIPTION
    Packages local code changes (backend, admin-portal, or both), securely transfers
    them to the AWS EC2 instance, rebuilds Docker containers, and runs health checks.
    Preserves database data and uploaded media volumes.

.PARAMETER Service
    Service to deploy: 'all' (default), 'backend', or 'admin' ('admin-portal').

.PARAMETER HostIP
    EC2 Public IP address or domain (default: 100.61.94.14).

.PARAMETER KeyPath
    Path to the AWS SSH private key (default: ~/.aws/lms-key.pem).

.EXAMPLE
    .\scripts\deploy_ec2.ps1
    Deploys both backend and admin-portal.

.EXAMPLE
    .\scripts\deploy_ec2.ps1 -Service backend
    Deploys only backend changes (much faster).

.EXAMPLE
    .\scripts\deploy_ec2.ps1 -Service admin
    Deploys only Admin Portal frontend changes.
#>

[CmdletBinding()]
param(
    [ValidateSet('all', 'backend', 'admin', 'admin-portal')]
    [string]$Service = 'all',

    [string]$HostIP = '100.61.94.14',

    [string]$KeyPath = "$env:USERPROFILE\.aws\lms-key.pem",

    [string]$User = 'ubuntu',

    [string]$RemoteDir = '/opt/lms'
)

$ErrorActionPreference = 'Stop'

# Map friendly service names
$composeTarget = switch ($Service) {
    'admin'        { 'admin-portal' }
    'admin-portal' { 'admin-portal' }
    'backend'      { 'backend' }
    default        { 'backend admin-portal' }
}

Write-Host "==========================================================" -ForegroundColor Cyan
Write-Host "       Axisora Forge LMS - Automated EC2 Deployer         " -ForegroundColor Cyan
Write-Host "==========================================================" -ForegroundColor Cyan
Write-Host "  Target Host  : $User@$HostIP" -ForegroundColor Yellow
Write-Host "  Service(s)   : $Service (Docker: $composeTarget)" -ForegroundColor Yellow
Write-Host "  SSH Key      : $KeyPath" -ForegroundColor Yellow
Write-Host "==========================================================" -ForegroundColor Cyan

# 1. Verify SSH key exists
if (-not (Test-Path $KeyPath)) {
    Write-Host "[ERROR] SSH key not found at: $KeyPath" -ForegroundColor Red
    Write-Host "Please pass the correct path using -KeyPath <path-to-pem>" -ForegroundColor Red
    exit 1
}

# 2. Verify root directory
$projectRoot = Resolve-Path "$PSScriptRoot\.."
Set-Location $projectRoot

# 3. Determine folders to package
$foldersToPack = @('docker')
if ($Service -eq 'all') {
    $foldersToPack += @('backend', 'admin-portal', 'scripts')
} elseif ($Service -eq 'backend') {
    $foldersToPack += @('backend')
} else {
    $foldersToPack += @('admin-portal')
}

$tempArchive = "$projectRoot\deploy_temp_$(Get-Random).tar.gz"

try {
    # 4. Create compressed package excluding build artifacts & node_modules
    Write-Host "`n[1/5] Compressing source files ($($foldersToPack -join ', '))..." -ForegroundColor Green
    $excludeArgs = @(
        '--exclude=target',
        '--exclude=node_modules',
        '--exclude=.angular',
        '--exclude=.git',
        '--exclude=.idea',
        '--exclude=.vscode',
        '--exclude=mobile-app',
        '--exclude=*.tar.gz',
        '--exclude=*.log'
    )
    
    $tarArgs = $excludeArgs + @('-czf', $tempArchive) + $foldersToPack
    & tar $tarArgs
    
    if (-not (Test-Path $tempArchive)) {
        throw "Failed to create deployment archive."
    }
    $archiveSizeMB = [math]::Round((Get-Item $tempArchive).Length / 1MB, 2)
    Write-Host "      Archive created successfully: $archiveSizeMB MB" -ForegroundColor Gray

    # 5. SCP archive to EC2
    Write-Host "`n[2/5] Uploading package to EC2 (/tmp/deploy_bundle.tar.gz)..." -ForegroundColor Green
    & scp -i $KeyPath -o StrictHostKeyChecking=no -o ConnectTimeout=10 $tempArchive "${User}@${HostIP}:/tmp/deploy_bundle.tar.gz"
    if ($LASTEXITCODE -ne 0) {
        throw "Failed to transfer archive via SCP."
    }
    Write-Host "      Upload complete." -ForegroundColor Gray

    # 6. Extract on EC2 and rebuild containers
    Write-Host "`n[3/5] Extracting update and rebuilding Docker container(s)..." -ForegroundColor Green
    Write-Host "      (This runs docker compose up -d --build $composeTarget)..." -ForegroundColor Gray

    $remoteCommands = @"
set -e
echo '--> Extracting source files into $RemoteDir...'
tar -xzf /tmp/deploy_bundle.tar.gz -C $RemoteDir/
rm -f /tmp/deploy_bundle.tar.gz

echo '--> Rebuilding container(s): $composeTarget...'
cd $RemoteDir/docker
docker compose up -d --build $composeTarget

echo '--> Current container status:'
docker compose ps
"@

    & ssh -i $KeyPath -o StrictHostKeyChecking=no "${User}@${HostIP}" $remoteCommands
    if ($LASTEXITCODE -ne 0) {
        throw "Remote deployment command failed."
    }

    # 7. Verification & Health Check
    Write-Host "`n[4/5] Verifying service health..." -ForegroundColor Green
    Start-Sleep -Seconds 5

    if ($Service -eq 'all' -or $Service -eq 'backend') {
        try {
            $backendHealth = Invoke-RestMethod -Uri "http://${HostIP}:8080/actuator/health" -TimeoutSec 10 -ErrorAction SilentlyContinue
            if ($backendHealth.status -eq 'UP') {
                Write-Host "      [OK] Backend Health: UP" -ForegroundColor Green
            } else {
                Write-Host "      [WAIT] Backend is still starting up..." -ForegroundColor Yellow
            }
        } catch {
            Write-Host "      [WAIT] Backend is starting up. Check status in a few seconds." -ForegroundColor Yellow
        }
    }

    if ($Service -eq 'all' -or $Service -like 'admin*') {
        try {
            $adminCheck = Invoke-WebRequest -Uri "http://${HostIP}" -UseBasicParsing -TimeoutSec 10 -ErrorAction SilentlyContinue
            if ($adminCheck.StatusCode -eq 200) {
                Write-Host "      [OK] Admin Portal HTTP 200: UP" -ForegroundColor Green
            }
        } catch {
            Write-Host "      [WARN] Admin Portal check returned: $_" -ForegroundColor Yellow
        }
    }

    # 8. Success Summary
    Write-Host "`n[5/5] Deployment Finished Successfully!" -ForegroundColor Green
    Write-Host "==========================================================" -ForegroundColor Cyan
    Write-Host "  Admin Portal : http://${HostIP}" -ForegroundColor White
    Write-Host "  Backend API  : http://${HostIP}:8080" -ForegroundColor White
    Write-Host "  Swagger UI   : http://${HostIP}:8080/swagger-ui/index.html" -ForegroundColor White
    Write-Host "  OpenAPI Spec : http://${HostIP}/api-docs" -ForegroundColor White
    Write-Host "==========================================================" -ForegroundColor Cyan

} finally {
    # Always clean up local temporary archive
    if (Test-Path $tempArchive) {
        Remove-Item -Force $tempArchive -ErrorAction SilentlyContinue
    }
}

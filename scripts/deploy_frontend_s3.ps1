# ==============================================================================
# Script: deploy_frontend_s3.ps1
# Purpose: Build and deploy Angular Admin Portal to AWS S3 & CloudFront (Architecture A)
# Usage:
#   .\scripts\deploy_frontend_s3.ps1 -BucketName "my-bucket" -DistributionId "E123456789"
# ==============================================================================

param (
    [Parameter(Mandatory=$false)]
    [string]$BucketName = $env:S3_BUCKET_NAME,

    [Parameter(Mandatory=$false)]
    [string]$DistributionId = $env:CLOUDFRONT_DIST_ID,

    [Parameter(Mandatory=$false)]
    [switch]$NoVerifySsl = $true
)

$ErrorActionPreference = "Stop"
$ScriptDir = Split-Path -Parent $MyInvocation.MyCommand.Path
$RootDir = Split-Path -Parent $ScriptDir

# Locate aws executable
$AwsCmd = "aws"
if (-not (Get-Command "aws" -ErrorAction SilentlyContinue)) {
    $PotentialPaths = @(
        "$env:LOCALAPPDATA\Programs\Amazon\AWSCLIV2\aws.exe",
        "C:\Program Files\Amazon\AWSCLIV2\aws.exe",
        "C:\Program Files (x86)\Amazon\AWSCLIV2\aws.exe"
    )
    foreach ($p in $PotentialPaths) {
        if (Test-Path $p) {
            $AwsCmd = $p
            break
        }
    }
}

$SslArgs = if ($NoVerifySsl) { @("--no-verify-ssl") } else { @() }

# Try loading from .env if present and parameters not provided
if ((-not $BucketName) -and (Test-Path "$RootDir\.env")) {
    Get-Content "$RootDir\.env" | ForEach-Object {
        $line = $_.Trim()
        if ($line -and -not $line.StartsWith("#") -and $line.Contains("=")) {
            $parts = $line.Split("=", 2)
            $key = $parts[0].Trim()
            $val = $parts[1].Trim()
            if ($key -eq "S3_BUCKET_NAME") { $BucketName = $val }
            if ($key -eq "CLOUDFRONT_DIST_ID") { $DistributionId = $val }
        }
    }
}

if (-not $BucketName) {
    Write-Error "ERROR: S3 bucket name is required. Specify -BucketName or set S3_BUCKET_NAME in .env"
    exit 1
}

Write-Host "=== Deploying Angular Admin Portal to AWS S3 / CloudFront ===" -ForegroundColor Cyan
Write-Host "Target S3 Bucket:       $BucketName"
Write-Host "CloudFront Dist ID:     $($DistributionId ?? '<None specified>')"
Write-Host ""

# 1. Build Angular production bundle
Write-Host "[1/4] Building Angular Admin Portal for production..." -ForegroundColor Yellow
Set-Location "$RootDir\admin-portal"
npm run build -- --configuration production

$DistPath = "$RootDir\admin-portal\dist\admin-portal"
if (-not (Test-Path $DistPath)) {
    Write-Error "ERROR: Build directory $DistPath does not exist!"
    exit 1
}

# 2. Sync hashed immutable assets (JS, CSS, fonts, images) with 1-year cache
Write-Host "[2/4] Syncing hashed assets to s3://$BucketName with aggressive caching..." -ForegroundColor Yellow
& $AwsCmd s3 sync "$DistPath" "s3://$BucketName" --delete --exclude "index.html" --cache-control "public, max-age=31536000, immutable" @SslArgs

# 3. Sync index.html with no-cache headers to prevent stale SPA caches
Write-Host "[3/4] Uploading index.html with no-cache headers..." -ForegroundColor Yellow
& $AwsCmd s3 cp "$DistPath\index.html" "s3://$BucketName/index.html" --cache-control "no-cache, no-store, must-revalidate" --content-type "text/html" @SslArgs

# 4. Invalidate CloudFront distribution if provided
if ($DistributionId) {
    Write-Host "[4/4] Invalidating CloudFront cache for distribution $DistributionId..." -ForegroundColor Yellow
    & $AwsCmd cloudfront create-invalidation --distribution-id $DistributionId --paths "/*" @SslArgs
    Write-Host "CloudFront invalidation triggered successfully!" -ForegroundColor Green
} else {
    Write-Host "[4/4] Skipping CloudFront invalidation (no distribution ID provided)." -ForegroundColor DarkGray
}

Write-Host ""
Write-Host "=== Frontend Deployment Complete ===" -ForegroundColor Green
Set-Location $RootDir

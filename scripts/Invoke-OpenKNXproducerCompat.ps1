param(
    [Parameter(Mandatory = $true)]
    [string]$XmlFile,

    [string]$HeaderFile = "include/knxprod.h",

    [string]$OutputFile = ""
)

$ErrorActionPreference = "Stop"

$producer = Join-Path $env:USERPROFILE "bin/OpenKNXproducer.exe"
if (-not (Test-Path $producer)) {
    throw "OpenKNXproducer not found at $producer"
}

$createArgs = @(
    "create",
    "--Debug",
    "--NoXsd",
    "-h",
    $HeaderFile,
    $XmlFile
)

$createOutput = & $producer @createArgs 2>&1
$createExitCode = $LASTEXITCODE
if ($createExitCode -eq 0) {
    foreach ($line in $createOutput) {
        $line
    }
    exit 0
}

$createText = $createOutput | Out-String
if ($createText -notmatch "Invalid name character in 'op:") {
    foreach ($line in $createOutput) {
        $line
    }
    exit $createExitCode
}

$debugFile = [System.IO.Path]::ChangeExtension($XmlFile, "debug.xml")
if (-not (Test-Path $debugFile)) {
    foreach ($line in $createOutput) {
        $line
    }
    exit $createExitCode
}

$compatibilityNoticePrinted = $false
foreach ($line in $createOutput) {
    if ($line -match '^Error during knxprod file generation:') {
        Write-Output 'OpenKNXproducer signing compatibility issue detected, retrying with sanitized debug XML...'
        $compatibilityNoticePrinted = $true
        break
    }

    $line
}

if (-not $compatibilityNoticePrinted) {
    Write-Output 'OpenKNXproducer signing compatibility issue detected, retrying with sanitized debug XML...'
}

$compatFile = Join-Path ([System.IO.Path]::GetDirectoryName($debugFile)) (([System.IO.Path]::GetFileNameWithoutExtension($debugFile)) + ".compat.xml")
$content = Get-Content -Path $debugFile -Raw
$content = $content -replace '\s+xmlns:op="[^"]*"', ''
$content = [regex]::Replace($content, '\s+op:[A-Za-z0-9_-]+="[^"]*"', '')
$content = [regex]::Replace($content, '<op:[A-Za-z0-9_-]+\b[^>]*/>', '')
$content = [regex]::Replace($content, '<op:[A-Za-z0-9_-]+\b[^>]*>.*?</op:[A-Za-z0-9_-]+>', '', [System.Text.RegularExpressions.RegexOptions]::Singleline)
Set-Content -Path $compatFile -Value $content -Encoding UTF8

$resolvedOutput = $OutputFile
if ([string]::IsNullOrWhiteSpace($resolvedOutput)) {
    $resolvedOutput = [System.IO.Path]::ChangeExtension($XmlFile, "knxprod")
}

try {
    $compatOutput = & $producer "knxprod" "--NoXsd" "--Output" $resolvedOutput $compatFile 2>&1
    foreach ($line in $compatOutput) {
        $line
    }
    exit $LASTEXITCODE
}
finally {
    if (Test-Path $compatFile) {
        Remove-Item -Path $compatFile -Force
    }
}
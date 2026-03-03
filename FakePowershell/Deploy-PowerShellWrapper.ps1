# Deploy-PowerShellWrapper.ps1
# Deploys the PowerShell wrapper to replace system PowerShell
# THIS MODIFIES SYSTEM FILES - BACKUP IS CRITICAL

#Requires -RunAsAdministrator

Write-Host "================================================================" -ForegroundColor Red
Write-Host " CRITICAL SYSTEM MODIFICATION" -ForegroundColor Red
Write-Host " This will replace C:\Windows\System32\WindowsPowerShell\v1.0\powershell.exe" -ForegroundColor Red
Write-Host "================================================================" -ForegroundColor Red
Write-Host ""
Write-Host "This is for RESEARCH/HONEYPOT environments ONLY!" -ForegroundColor Yellow
Write-Host "Do NOT deploy on production systems!" -ForegroundColor Yellow
Write-Host ""

$response = Read-Host "Type 'DEPLOY' to continue (anything else cancels)"
if ($response -ne "DEPLOY") {
    Write-Host "Deployment cancelled" -ForegroundColor Green
    exit 0
}

Write-Host ""
Write-Host "[*] PowerShell Wrapper Deployment" -ForegroundColor Cyan
Write-Host ""

# Paths
$psDir = "C:\Windows\System32\WindowsPowerShell\v1.0"
$originalPS = "$psDir\powershell.exe"
$realPS = "$psDir\powershell_quantum.exe"
$wrapperPS = ".\powershell.exe"
$backupDir = "C:\ProgramData\Quantum Research\Backups"
$timestampBackup = "$backupDir\powershell.exe.backup-$(Get-Date -Format 'yyyyMMdd-HHmmss')"

# Check if wrapper exists
if (!(Test-Path $wrapperPS)) {
    Write-Host "[ERROR] Wrapper not found!" -ForegroundColor Red
    Write-Host "Expected location: $wrapperPS" -ForegroundColor Red
    Write-Host ""
    Write-Host "You need to compile it first:" -ForegroundColor Yellow
    Write-Host "  1. Run BUILD-WRAPPER.bat" -ForegroundColor Gray
    exit 1
}

Write-Host "[+] Wrapper found" -ForegroundColor Green
$wrapperSize = (Get-Item $wrapperPS).Length
Write-Host "    Size: $wrapperSize bytes" -ForegroundColor Gray
Write-Host ""

# Create backup directory
if (!(Test-Path $backupDir)) {
    New-Item -Path $backupDir -ItemType Directory -Force | Out-Null
}

# Check if already deployed
if (Test-Path $realPS) {
    Write-Host "[!] powershell_quantum.exe already exists!" -ForegroundColor Yellow
    Write-Host "    This might be from a previous deployment" -ForegroundColor Gray
    Write-Host ""
    
    $response = Read-Host "Continue anyway? (Y/N)"
    if ($response -ne 'Y' -and $response -ne 'y') {
        Write-Host "Deployment cancelled" -ForegroundColor Yellow
        exit 0
    }
    Write-Host ""
}

# Stop any running PowerShell processes (except current)
Write-Host "[+] Checking for other PowerShell processes..." -ForegroundColor Green
$otherPS = Get-Process -Name powershell -ErrorAction SilentlyContinue | Where-Object {$_.Id -ne $PID}

if ($otherPS) {
    Write-Host "    Found $($otherPS.Count) other PowerShell process(es)" -ForegroundColor Yellow
    Write-Host "    Waiting for them to close..." -ForegroundColor Gray
    
    $timeout = 30
    $elapsed = 0
    while ($otherPS -and $elapsed -lt $timeout) {
        Start-Sleep -Seconds 2
        $elapsed += 2
        $otherPS = Get-Process -Name powershell -ErrorAction SilentlyContinue | Where-Object {$_.Id -ne $PID}
    }
    
    if ($otherPS) {
        Write-Host "    [!] Some processes still running" -ForegroundColor Yellow
        Write-Host "    Deployment may fail if powershell.exe is in use" -ForegroundColor Yellow
    }
}

# Take ownership
Write-Host "[+] Taking ownership of PowerShell executable..." -ForegroundColor Green
try {
    takeown /F $originalPS /A 2>&1 | Out-Null
    icacls $originalPS /grant "Administrators:(F)" 2>&1 | Out-Null
    Write-Host "    Ownership acquired" -ForegroundColor Green
} catch {
    Write-Host "    [ERROR] Could not take ownership: $_" -ForegroundColor Red
    exit 1
}

# Backup original
Write-Host ""
Write-Host "[+] Creating backups..." -ForegroundColor Green

if (!(Test-Path $realPS)) {
    # First deployment - rename original
    try {
        Copy-Item $originalPS -Destination $timestampBackup -Force
        Write-Host "    Timestamped backup: $timestampBackup" -ForegroundColor Green
        
        Move-Item $originalPS -Destination $realPS -Force
        Write-Host "    Renamed to: powershell_quantum.exe" -ForegroundColor Green
    } catch {
        Write-Host "    [ERROR] Could not backup/rename: $_" -ForegroundColor Red
        exit 1
    }
} else {
    # Already deployed - just backup current state
    Copy-Item $realPS -Destination $timestampBackup -Force
    Write-Host "    Backup created: $timestampBackup" -ForegroundColor Green
}

# Deploy wrapper
Write-Host ""
Write-Host "[+] Deploying wrapper..." -ForegroundColor Green
try {
    Copy-Item $wrapperPS -Destination $originalPS -Force
    Write-Host "    Wrapper installed as powershell.exe" -ForegroundColor Green
} catch {
    Write-Host "    [ERROR] Could not deploy wrapper: $_" -ForegroundColor Red
    Write-Host "    Attempting to restore from backup..." -ForegroundColor Yellow
    
    if (Test-Path $realPS) {
        Copy-Item $realPS -Destination $originalPS -Force
        Write-Host "    Restored from backup" -ForegroundColor Green
    }
    exit 1
}

# Verify deployment
Write-Host ""
Write-Host "[+] Verifying deployment..." -ForegroundColor Green

if ((Test-Path $originalPS) -and (Test-Path $realPS)) {
    $wrapperActual = (Get-Item $originalPS).Length
    $realActual = (Get-Item $realPS).Length
    
    Write-Host "    powershell.exe (wrapper): $wrapperActual bytes" -ForegroundColor Gray
    Write-Host "    powershell_quantum.exe (original): $realActual bytes" -ForegroundColor Gray
    
    if ($wrapperActual -eq $wrapperSize) {
        Write-Host "    [SUCCESS] Wrapper deployed correctly" -ForegroundColor Green
    } else {
        Write-Host "    [WARNING] Size mismatch - deployment may have failed" -ForegroundColor Yellow
    }
} else {
    Write-Host "    [ERROR] Files missing after deployment!" -ForegroundColor Red
}

# Test deployment
Write-Host ""
Write-Host "[+] Testing wrapper..." -ForegroundColor Green
Write-Host ""

try {
    $testResult = powershell -NoProfile -Command "Get-CimInstance Win32_ComputerSystem | Select Manufacturer, Model"
    $testResult | Format-Table -AutoSize
    
    if ($testResult.Manufacturer -notmatch "VMware") {
        Write-Host ""
        Write-Host "[SUCCESS] Wrapper is working!" -ForegroundColor Green
        Write-Host "The hook is loading and VM detection is BLOCKED!" -ForegroundColor Green
    } else {
        Write-Host ""
        Write-Host "[INFO] Wrapper is running, but still showing VMware" -ForegroundColor Yellow
        Write-Host "This might be expected if WMIHook.dll isn't deployed yet" -ForegroundColor Gray
    }
} catch {
    Write-Host ""
    Write-Host "[ERROR] Test failed: $_" -ForegroundColor Red
}

# Summary
Write-Host ""
Write-Host "================================================================" -ForegroundColor Cyan
Write-Host " Deployment Complete" -ForegroundColor Cyan
Write-Host "================================================================" -ForegroundColor Cyan
Write-Host ""
Write-Host "Files:" -ForegroundColor Yellow
Write-Host "  Wrapper:  $originalPS" -ForegroundColor Gray
Write-Host "  Original: $realPS" -ForegroundColor Gray
Write-Host "  Backup:   $timestampBackup" -ForegroundColor Gray
Write-Host ""
Write-Host "Configuration:" -ForegroundColor Yellow
Write-Host "  STRIP_NOPROFILE = true (removes -NoProfile flag)" -ForegroundColor Gray
Write-Host "  Hook DLL will load automatically" -ForegroundColor Gray
Write-Host ""
Write-Host "To ROLLBACK:" -ForegroundColor Yellow
Write-Host "  Run: .\Rollback-PowerShellWrapper.ps1" -ForegroundColor White
Write-Host ""
Write-Host "To TEST:" -ForegroundColor Yellow
Write-Host "  Run: .\Test-PowerShellWrapper.ps1" -ForegroundColor White
Write-Host ""

exit 0

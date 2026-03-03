# Rollback-PowerShellWrapper.ps1
# Restores original PowerShell and removes wrapper

#Requires -RunAsAdministrator

Write-Host "================================================================" -ForegroundColor Yellow
Write-Host " PowerShell Wrapper Rollback" -ForegroundColor Yellow
Write-Host " This will restore the original PowerShell" -ForegroundColor Yellow
Write-Host "================================================================" -ForegroundColor Yellow
Write-Host ""

$psDir = "C:\Windows\System32\WindowsPowerShell\v1.0"
$originalPS = "$psDir\powershell.exe"
$realPS = "$psDir\powershell_real.exe"

# Check if wrapper is deployed
if (!(Test-Path $realPS)) {
    Write-Host "[!] powershell_real.exe not found" -ForegroundColor Yellow
    Write-Host "    Wrapper may not be deployed, or already rolled back" -ForegroundColor Gray
    Write-Host ""
    exit 0
}

Write-Host "[+] Backup found: powershell_real.exe" -ForegroundColor Green
Write-Host "    Size: $((Get-Item $realPS).Length) bytes" -ForegroundColor Gray
Write-Host ""

$response = Read-Host "Proceed with rollback? (Y/N)"
if ($response -ne 'Y' -and $response -ne 'y') {
    Write-Host "Rollback cancelled" -ForegroundColor Yellow
    exit 0
}

Write-Host ""
Write-Host "[+] Beginning rollback..." -ForegroundColor Green
Write-Host ""

# Take ownership
Write-Host "[+] Taking ownership..." -ForegroundColor Green
takeown /F $originalPS /A 2>&1 | Out-Null
icacls $originalPS /grant "Administrators:(F)" 2>&1 | Out-Null

# Remove wrapper
Write-Host "[+] Removing wrapper..." -ForegroundColor Green
try {
    Remove-Item $originalPS -Force
    Write-Host "    Wrapper removed" -ForegroundColor Green
} catch {
    Write-Host "    [ERROR] Could not remove wrapper: $_" -ForegroundColor Red
    exit 1
}

# Restore original
Write-Host "[+] Restoring original PowerShell..." -ForegroundColor Green
try {
    Move-Item $realPS -Destination $originalPS -Force
    Write-Host "    Original restored" -ForegroundColor Green
} catch {
    Write-Host "    [ERROR] Could not restore original: $_" -ForegroundColor Red
    Write-Host "    CRITICAL: PowerShell may be in broken state!" -ForegroundColor Red
    Write-Host "    Manually copy powershell_real.exe to powershell.exe" -ForegroundColor Yellow
    exit 1
}

# Test
Write-Host ""
Write-Host "[+] Testing restoration..." -ForegroundColor Green
Write-Host ""

try {
    $result = powershell -NoProfile -Command "Get-CimInstance Win32_ComputerSystem | Select Manufacturer, Model"
    $result | Format-Table -AutoSize
    
    if ($result.Manufacturer -match "VMware|VirtualBox|QEMU") {
        Write-Host ""
        Write-Host "[SUCCESS] Rollback successful!" -ForegroundColor Green
        Write-Host "Original PowerShell behavior restored." -ForegroundColor Green
        Write-Host "VM is now detectable again (as expected)." -ForegroundColor Green
    } else {
        Write-Host ""
        Write-Host "[INFO] Restored, but still showing non-VM hardware" -ForegroundColor Yellow
        Write-Host "Your CimD module or other hooks may still be active" -ForegroundColor Gray
    }
} catch {
    Write-Host ""
    Write-Host "[ERROR] Test failed: $_" -ForegroundColor Red
}

Write-Host ""
Write-Host "================================================================" -ForegroundColor Green
Write-Host " Rollback Complete" -ForegroundColor Green
Write-Host "================================================================" -ForegroundColor Green
Write-Host ""
Write-Host "Original PowerShell has been restored." -ForegroundColor White
Write-Host ""
Write-Host "To redeploy the wrapper:" -ForegroundColor Yellow
Write-Host "  Run: .\Deploy-PowerShellWrapper.ps1" -ForegroundColor Gray
Write-Host ""

exit 0

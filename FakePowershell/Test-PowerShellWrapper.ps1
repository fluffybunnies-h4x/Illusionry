# Test-PowerShellWrapper.ps1
# Comprehensive testing of PowerShell wrapper deployment

Write-Host "================================================================" -ForegroundColor Cyan
Write-Host " PowerShell Wrapper Test Suite" -ForegroundColor Cyan
Write-Host "================================================================" -ForegroundColor Cyan
Write-Host ""

$testsPassed = 0
$testsFailed = 0

# Test 1: Check if files exist
Write-Host "[Test 1] Checking file structure..." -ForegroundColor Yellow

$psDir = "C:\Windows\System32\WindowsPowerShell\v1.0"
$originalPS = "$psDir\powershell.exe"
$realPS = "$psDir\powershell_quantum.exe"

if ((Test-Path $originalPS) -and (Test-Path $realPS)) {
    Write-Host "  powershell.exe exists: YES" -ForegroundColor White
    Write-Host "  powershell_quantum.exe exists: YES" -ForegroundColor White
    Write-Host "  [PASS] File structure correct" -ForegroundColor Green
    $testsPassed++
} else {
    Write-Host "  [FAIL] File structure incorrect" -ForegroundColor Red
    Write-Host "  Wrapper may not be deployed" -ForegroundColor Yellow
    $testsFailed++
}
Write-Host ""

# Test 2: Test normal PowerShell execution
Write-Host "[Test 2] Testing normal PowerShell execution..." -ForegroundColor Yellow
try {
    $result = powershell -Command "Write-Output 'test'"
    if ($result -eq 'test') {
        Write-Host "  [PASS] PowerShell executes normally" -ForegroundColor Green
        $testsPassed++
    } else {
        Write-Host "  [FAIL] Unexpected output" -ForegroundColor Red
        $testsFailed++
    }
} catch {
    Write-Host "  [FAIL] PowerShell execution failed: $_" -ForegroundColor Red
    $testsFailed++
}
Write-Host ""

# Test 3: Test with -NoProfile (CRITICAL)
Write-Host "[Test 3] Testing -NoProfile flag (CRITICAL TEST)..." -ForegroundColor Yellow
try {
    $result = powershell -NoProfile -Command "Get-CimInstance Win32_ComputerSystem | Select Manufacturer, Model | ConvertTo-Json" | ConvertFrom-Json
    
    Write-Host "  Manufacturer: $($result.Manufacturer)" -ForegroundColor White
    Write-Host "  Model: $($result.Model)" -ForegroundColor White
    
    if ($result.Manufacturer -notmatch "VMware|VirtualBox|QEMU") {
        Write-Host "  [PASS] VM detection BLOCKED with -NoProfile!" -ForegroundColor Green
        $testsPassed++
    } else {
        Write-Host "  [FAIL] Still detecting VM" -ForegroundColor Red
        Write-Host "  Note: Hook DLL may not be loading" -ForegroundColor Yellow
        $testsFailed++
    }
} catch {
    Write-Host "  [FAIL] Query failed: $_" -ForegroundColor Red
    $testsFailed++
}
Write-Host ""

# Test 4: Verify -NoProfile is actually stripped
Write-Host "[Test 4] Verifying -NoProfile is stripped..." -ForegroundColor Yellow

# Check if profile modules loaded (they should, since -NoProfile was stripped)
$modulesLoaded = powershell -NoProfile -Command "Get-Module | Select-Object -ExpandProperty Name" 2>$null

if ($modulesLoaded -contains "CimD") {
    Write-Host "  CimD module loaded: YES (good - means -NoProfile was stripped)" -ForegroundColor White
    Write-Host "  [PASS] -NoProfile flag is being stripped" -ForegroundColor Green
    $testsPassed++
} else {
    Write-Host "  CimD module loaded: NO" -ForegroundColor White
    Write-Host "  [INFO] This is OK if you're relying on DLL hook instead" -ForegroundColor Gray
}
Write-Host ""

# Test 5: Malware simulation
Write-Host "[Test 5] Malware detection simulation..." -ForegroundColor Yellow
powershell -NoProfile -Command "if((Get-CimInstance Win32_ComputerSystem).Manufacturer -match 'VMware'){ exit 0 } else { exit 1 }" 2>$null
$exitCode = $LASTEXITCODE

Write-Host "  Exit Code: $exitCode" -ForegroundColor White
if ($exitCode -eq 1) {
    Write-Host "  [PASS] Malware would NOT detect VM!" -ForegroundColor Green
    $testsPassed++
} else {
    Write-Host "  [FAIL] Malware WOULD detect VM" -ForegroundColor Red
    $testsFailed++
}
Write-Host ""

# Test 6: Check wrapper logging (if enabled)
Write-Host "[Test 6] Checking wrapper logs..." -ForegroundColor Yellow
$logPath = "C:\ProgramData\Quantum Research\Logs\powershell-wrapper.log"

if (Test-Path $logPath) {
    $logLines = Get-Content $logPath -Tail 5
    Write-Host "  Log file exists: YES" -ForegroundColor White
    Write-Host "  Recent entries:" -ForegroundColor Gray
    $logLines | ForEach-Object { Write-Host "    $_" -ForegroundColor DarkGray }
    Write-Host "  [INFO] Logging is enabled" -ForegroundColor Gray
} else {
    Write-Host "  Log file exists: NO" -ForegroundColor White
    Write-Host "  [INFO] Logging is disabled (this is normal)" -ForegroundColor Gray
}
Write-Host ""

# Summary
Write-Host "================================================================" -ForegroundColor Cyan
Write-Host " Test Summary" -ForegroundColor Cyan
Write-Host "================================================================" -ForegroundColor Cyan
Write-Host ""
Write-Host "Tests Passed: $testsPassed" -ForegroundColor Green
Write-Host "Tests Failed: $testsFailed" -ForegroundColor Red
Write-Host ""

if ($testsFailed -eq 0) {
    Write-Host "[SUCCESS] All tests passed!" -ForegroundColor Green
    Write-Host "PowerShell wrapper is working correctly." -ForegroundColor Green
    Write-Host ""
    Write-Host "Your malware should now execute properly:" -ForegroundColor Cyan
    Write-Host "  - -NoProfile flag is stripped automatically" -ForegroundColor Gray
    Write-Host "  - WMI hook loads with every PowerShell call" -ForegroundColor Gray
    Write-Host "  - VM detection returns 'Dell Inc.'" -ForegroundColor Gray
} else {
    Write-Host "[FAILURE] Some tests failed" -ForegroundColor Red
    Write-Host ""
    Write-Host "Troubleshooting:" -ForegroundColor Yellow
    Write-Host "  1. Verify deployment: .\Deploy-PowerShellWrapper.ps1" -ForegroundColor Gray
    Write-Host "  2. Check WMIHook.dll exists and loads" -ForegroundColor Gray
    Write-Host "  3. Review wrapper configuration in PowerShellWrapper.cs" -ForegroundColor Gray
}

Write-Host ""
exit $testsFailed

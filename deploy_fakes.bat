@echo off
:: ============================================================
:: deploy_fakes.bat
:: Deploys fake systeminfo.exe and fake wmic.exe
:: Must be run as Administrator
:: ============================================================

net session >nul 2>&1
if %errorlevel% neq 0 (
    echo [ERROR] This script must be run as Administrator.
    pause
    exit /b 1
)

:: ============================================================
:: Verify source binaries exist before doing anything
:: ============================================================

if not exist "%~dp0systeminfo.exe" (
    echo [ERROR] systeminfo.exe not found next to this script.
    pause
    exit /b 1
)

if not exist "%~dp0wmic.exe" (
    echo [ERROR] wmic.exe not found next to this script.
    pause
    exit /b 1
)

:: ============================================================
:: SYSTEMINFO.EXE
:: Target: C:\Windows\System32\systeminfo.exe
:: ============================================================

echo [*] Deploying fake systeminfo.exe...

takeown /f C:\Windows\System32\systeminfo.exe
if %errorlevel% neq 0 (
    echo [ERROR] takeown failed for systeminfo.exe
    pause
    exit /b 1
)

icacls C:\Windows\System32\systeminfo.exe /grant Administrators:F
if %errorlevel% neq 0 (
    echo [ERROR] icacls failed for systeminfo.exe
    pause
    exit /b 1
)

del C:\Windows\System32\systeminfo.exe
if %errorlevel% neq 0 (
    echo [ERROR] del failed for systeminfo.exe
    pause
    exit /b 1
)

move "%~dp0systeminfo.exe" C:\Windows\System32\systeminfo.exe
if %errorlevel% neq 0 (
    echo [ERROR] move failed for systeminfo.exe
    pause
    exit /b 1
)

echo [+] systeminfo.exe deployed successfully.

:: ============================================================
:: WMIC.EXE
:: Target: C:\Windows\System32\wbem\wmic.exe
:: ============================================================

echo [*] Deploying fake wmic.exe...

takeown /f C:\Windows\System32\wbem\wmic.exe
if %errorlevel% neq 0 (
    echo [ERROR] takeown failed for wmic.exe
    pause
    exit /b 1
)

icacls C:\Windows\System32\wbem\wmic.exe /grant Administrators:F
if %errorlevel% neq 0 (
    echo [ERROR] icacls failed for wmic.exe
    pause
    exit /b 1
)

rename C:\Windows\System32\wbem\wmic.exe wmic.exe.bak
if %errorlevel% neq 0 (
    echo [ERROR] rename failed for wmic.exe
    pause
    exit /b 1
)

move "%~dp0wmic.exe" C:\Windows\System32\wbem\wmic.exe
if %errorlevel% neq 0 (
    echo [ERROR] move failed for wmic.exe
    pause
    exit /b 1
)

echo [+] wmic.exe deployed successfully.

:: ============================================================

echo.
echo [+] All fakes deployed. Verify with:
echo     systeminfo
echo     wmic os get caption
echo.
pause
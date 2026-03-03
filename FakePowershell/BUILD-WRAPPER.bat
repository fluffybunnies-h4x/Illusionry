@echo off
REM BUILD-WRAPPER.bat
REM Compiles the PowerShell wrapper

echo ============================================
echo  PowerShell Wrapper Build Script
echo ============================================
echo.

REM Check for C# compiler
where csc.exe >nul 2>&1
if %ERRORLEVEL% NEQ 0 (
    echo [ERROR] csc.exe not found!
    echo.
    echo Please run from "Developer Command Prompt for VS 2022"
    echo Or run from "x64 Native Tools Command Prompt for VS 2022"
    echo.
    pause
    exit /b 1
)

echo [+] C# compiler found
echo.

REM Clean previous build
if exist powershell.exe del powershell.exe

echo [+] Compiling PowerShellWrapper.cs...
echo.

REM Compile as x64 executable
csc /out:powershell.exe /platform:x64 /optimize+ PowerShellWrapper.cs

if %ERRORLEVEL% NEQ 0 (
    echo.
    echo [ERROR] Compilation failed!
    pause
    exit /b 1
)

echo.
echo [+] Build successful!
echo.

dir /B powershell.exe 2>nul

if %ERRORLEVEL% EQU 0 (
    echo.
    echo [SUCCESS] powershell.exe wrapper created!
    echo.
    echo Next steps:
    echo   1. Review the wrapper code to adjust settings if needed
    echo   2. Run Deploy-PowerShellWrapper.ps1 as Administrator
    echo   3. Test with Test-PowerShellWrapper.ps1
    echo.
) else (
    echo.
    echo [ERROR] Executable not found after build
    echo.
)

pause

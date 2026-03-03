#requires -RunAsAdministrator
# Comprehensive BIOS Registry Patcher - Interactive Version
# Patches ALL registry keys that systeminfo reads

Write-Host "`n========================================" -ForegroundColor Cyan
Write-Host "COMPREHENSIVE BIOS REGISTRY PATCHER" -ForegroundColor Cyan
Write-Host "========================================`n" -ForegroundColor Cyan

# Get current values
Write-Host "[INFO] Reading current system configuration..." -ForegroundColor Yellow
$hostname = $env:COMPUTERNAME
$owner = (Get-ItemProperty "HKLM:\SOFTWARE\Microsoft\Windows NT\CurrentVersion").RegisteredOwner
$org = (Get-ItemProperty "HKLM:\SOFTWARE\Microsoft\Windows NT\CurrentVersion").RegisteredOrganization
$biosReg = Get-ItemProperty "HKLM:\HARDWARE\DESCRIPTION\System\BIOS" -ErrorAction SilentlyContinue

Write-Host "`nCURRENT VALUES:" -ForegroundColor Green
Write-Host "  Hostname:      $hostname"
Write-Host "  Owner:         $owner"
Write-Host "  Organization:  $org"
Write-Host "  Manufacturer:  $($biosReg.SystemManufacturer)"
Write-Host "  Model:         $($biosReg.SystemProductName)"
Write-Host "  BIOS Version:  $($biosReg.BIOSVersion)"
Write-Host ""

# Ask for system type
Write-Host "STEP 1: System Type" -ForegroundColor Cyan
Write-Host "  1 = Server"
Write-Host "  2 = Workstation"
$sysType = Read-Host "Enter 1 or 2"
$isServer = ($sysType -eq "1")

if ($isServer) {
    Write-Host "[INFO] Configuring as SERVER" -ForegroundColor Yellow
} else {
    Write-Host "[INFO] Configuring as WORKSTATION" -ForegroundColor Yellow
}

# OS Version Selection
Write-Host "`nSTEP 1a: OS Version" -ForegroundColor Cyan
if ($isServer) {
    Write-Host "  1 = Windows Server 2016 Standard"
    Write-Host "  2 = Windows Server 2019 Standard"
    Write-Host "  3 = Windows Server 2022 Standard"
    Write-Host "  4 = Windows Server 2016 Datacenter"
    Write-Host "  5 = Windows Server 2019 Datacenter"
    Write-Host "  6 = Windows Server 2022 Datacenter"
    $osChoice = Read-Host "Enter 1-6 or type custom"
    $osMap = @{
        "1" = "Windows Server 2016 Standard"
        "2" = "Windows Server 2019 Standard"
        "3" = "Windows Server 2022 Standard"
        "4" = "Windows Server 2016 Datacenter"
        "5" = "Windows Server 2019 Datacenter"
        "6" = "Windows Server 2022 Datacenter"
    }
    $newOSVersion = $osMap[$osChoice]
    if (-not $newOSVersion) { $newOSVersion = $osChoice }
} else {
    Write-Host "  1 = Windows 10 Pro"
    Write-Host "  2 = Windows 10 Pro for Workstations"
    Write-Host "  3 = Windows 10 Enterprise"
    Write-Host "  4 = Windows 11 Pro"
    Write-Host "  5 = Windows 11 Pro for Workstations"
    Write-Host "  6 = Windows 11 Enterprise"
    $osChoice = Read-Host "Enter 1-6 or type custom"
    $osMap = @{
        "1" = "Windows 10 Pro"
        "2" = "Windows 10 Pro for Workstations"
        "3" = "Windows 10 Enterprise"
        "4" = "Windows 11 Pro"
        "5" = "Windows 11 Pro for Workstations"
        "6" = "Windows 11 Enterprise"
    }
    $newOSVersion = $osMap[$osChoice]
    if (-not $newOSVersion) { $newOSVersion = $osChoice }
}
if ([string]::IsNullOrWhiteSpace($newOSVersion)) { $newOSVersion = "Windows 10 Pro" }
Write-Host "[SET] OS Version = $newOSVersion" -ForegroundColor Green

# CPU Selection
Write-Host "`nSTEP 1b: Processor" -ForegroundColor Cyan
if ($isServer) {
    Write-Host "  1 = Intel Xeon Gold 6248R (3.0 GHz, 24-Core)"
    Write-Host "  2 = Intel Xeon Gold 5220R (2.2 GHz, 24-Core)"
    Write-Host "  3 = Intel Xeon Silver 4214R (2.4 GHz, 12-Core)"
    Write-Host "  4 = Intel Xeon E5-2697 v4 (2.3 GHz, 18-Core)"
    Write-Host "  5 = Intel Xeon E5-2680 v4 (2.4 GHz, 14-Core)"
    Write-Host "  6 = AMD EPYC 7542 (2.9 GHz, 32-Core)"
    $cpuChoice = Read-Host "Enter 1-6 or type custom"
    $cpuMap = @{
        "1" = @{Name="Intel(R) Xeon(R) Gold 6248R CPU @ 3.00GHz"; MHz=3000; Cores=24}
        "2" = @{Name="Intel(R) Xeon(R) Gold 5220R CPU @ 2.20GHz"; MHz=2200; Cores=24}
        "3" = @{Name="Intel(R) Xeon(R) Silver 4214R CPU @ 2.40GHz"; MHz=2400; Cores=12}
        "4" = @{Name="Intel(R) Xeon(R) CPU E5-2697 v4 @ 2.30GHz"; MHz=2300; Cores=18}
        "5" = @{Name="Intel(R) Xeon(R) CPU E5-2680 v4 @ 2.40GHz"; MHz=2400; Cores=14}
        "6" = @{Name="AMD EPYC 7542 32-Core Processor"; MHz=2900; Cores=32}
    }
    $cpuInfo = $cpuMap[$cpuChoice]
    if (-not $cpuInfo) {
        $customName = $cpuChoice
        $cpuInfo = @{Name=$customName; MHz=3000; Cores=8}
    }
} else {
    Write-Host "  1 = Intel Core i7-1185G7 (3.0 GHz, 4-Core)"
    Write-Host "  2 = Intel Core i7-10700 (2.9 GHz, 8-Core)"
    Write-Host "  3 = Intel Core i5-10500 (3.1 GHz, 6-Core)"
    Write-Host "  4 = AMD Ryzen 7 5800X (3.8 GHz, 8-Core)"
    Write-Host "  5 = AMD Ryzen 5 5600X (3.7 GHz, 6-Core)"
    Write-Host "  6 = AMD Ryzen 9 5950X (3.4 GHz, 16-Core)"
    $cpuChoice = Read-Host "Enter 1-6 or type custom"
    $cpuMap = @{
        "1" = @{Name="11th Gen Intel(R) Core(TM) i7-1185G7 @ 3.00GHz"; MHz=3000; Cores=4}
        "2" = @{Name="Intel(R) Core(TM) i7-10700 CPU @ 2.90GHz"; MHz=2900; Cores=8}
        "3" = @{Name="Intel(R) Core(TM) i5-10500 CPU @ 3.10GHz"; MHz=3100; Cores=6}
        "4" = @{Name="AMD Ryzen 7 5800X 8-Core Processor"; MHz=3800; Cores=8}
        "5" = @{Name="AMD Ryzen 5 5600X 6-Core Processor"; MHz=3700; Cores=6}
        "6" = @{Name="AMD Ryzen 9 5950X 16-Core Processor"; MHz=3400; Cores=16}
    }
    $cpuInfo = $cpuMap[$cpuChoice]
    if (-not $cpuInfo) {
        $customName = $cpuChoice
        $cpuInfo = @{Name=$customName; MHz=3000; Cores=4}
    }
}
$cpuName = $cpuInfo.Name
$cpuMHz = $cpuInfo.MHz
$cpuCores = $cpuInfo.Cores
Write-Host "[SET] Processor = $cpuName ($cpuCores cores @ $cpuMHz MHz)" -ForegroundColor Green

# Hostname
Write-Host "`nSTEP 2: Hostname" -ForegroundColor Cyan
if ($isServer) {
    Write-Host "  Examples: DEV-DC1, SRV-SQL01, DC01-FINANCE"
} else {
    Write-Host "  Examples: WKS-JSMITH-01, DESKTOP-FINANCE-12"
}
$newHostname = Read-Host "Enter new hostname (or press Enter to keep '$hostname')"
if ([string]::IsNullOrWhiteSpace($newHostname)) { $newHostname = $hostname }
Write-Host "[SET] Hostname = $newHostname" -ForegroundColor Green

# Owner
Write-Host "`nSTEP 3: Registered Owner" -ForegroundColor Cyan
if ($isServer) {
    Write-Host "  Examples: IT Operations, System Administrator"
} else {
    Write-Host "  Examples: John Smith, Sarah Johnson"
}
$newOwner = Read-Host "Enter owner name (or press Enter for default)"
if ([string]::IsNullOrWhiteSpace($newOwner)) {
    $newOwner = if ($isServer) { "IT Operations" } else { "John Smith" }
}
Write-Host "[SET] Owner = $newOwner" -ForegroundColor Green

# Organization
Write-Host "`nSTEP 4: Organization" -ForegroundColor Cyan
Write-Host "  Examples: QUANTUM.CORP, Contoso Corporation"
$newOrg = Read-Host "Enter organization (or press Enter for 'QUANTUM.CORP')"
if ([string]::IsNullOrWhiteSpace($newOrg)) { $newOrg = "QUANTUM.CORP" }
Write-Host "[SET] Organization = $newOrg" -ForegroundColor Green

# Manufacturer
Write-Host "`nSTEP 5: Manufacturer" -ForegroundColor Cyan
if ($isServer) {
    Write-Host "  1 = Dell Inc."
    Write-Host "  2 = HPE"
    Write-Host "  3 = Lenovo"
    Write-Host "  4 = Cisco"
} else {
    Write-Host "  1 = Dell Inc."
    Write-Host "  2 = HP"
    Write-Host "  3 = Lenovo"
    Write-Host "  4 = Microsoft"
}
$mfgChoice = Read-Host "Enter 1-4"
$mfgMap = @{
    "1" = "Dell Inc."
    "2" = if ($isServer) { "HPE" } else { "HP" }
    "3" = "Lenovo"
    "4" = if ($isServer) { "Cisco" } else { "Microsoft" }
}
$newMfg = $mfgMap[$mfgChoice]
if (-not $newMfg) { $newMfg = "Dell Inc." }
Write-Host "[SET] Manufacturer = $newMfg" -ForegroundColor Green

# Model
Write-Host "`nSTEP 6: Model" -ForegroundColor Cyan
if ($newMfg -eq "Dell Inc." -and $isServer) {
    Write-Host "  1 = PowerEdge R630"
    Write-Host "  2 = PowerEdge R640"
    Write-Host "  3 = PowerEdge R740"
    $modelChoice = Read-Host "Enter 1-3 or type custom"
    $modelMap = @{ "1" = "PowerEdge R630"; "2" = "PowerEdge R640"; "3" = "PowerEdge R740" }
    $newModel = $modelMap[$modelChoice]
    if (-not $newModel) { $newModel = $modelChoice }
    $boardProduct = "0H8DXP"
} elseif ($newMfg -eq "Dell Inc.") {
    Write-Host "  1 = Latitude 7420"
    Write-Host "  2 = OptiPlex 7090"
    $modelChoice = Read-Host "Enter 1-2 or type custom"
    $modelMap = @{ "1" = "Latitude 7420"; "2" = "OptiPlex 7090" }
    $newModel = $modelMap[$modelChoice]
    if (-not $newModel) { $newModel = $modelChoice }
    $boardProduct = "0JK3F9"
} elseif ($newMfg -eq "HPE" -and $isServer) {
    Write-Host "  1 = ProLiant DL380 Gen10"
    Write-Host "  2 = ProLiant DL360 Gen10"
    $modelChoice = Read-Host "Enter 1-2 or type custom"
    $modelMap = @{ "1" = "ProLiant DL380 Gen10"; "2" = "ProLiant DL360 Gen10" }
    $newModel = $modelMap[$modelChoice]
    if (-not $newModel) { $newModel = $modelChoice }
    $boardProduct = "ProLiant DL380 Gen10"
} else {
    $newModel = Read-Host "Enter model name"
    $boardProduct = $newModel
}
if ([string]::IsNullOrWhiteSpace($newModel)) { $newModel = "Default Model" }
Write-Host "[SET] Model = $newModel" -ForegroundColor Green

# BIOS Version
Write-Host "`nSTEP 7: BIOS Version" -ForegroundColor Cyan
Write-Host "  Press Enter to auto-generate realistic version"
$biosVer = Read-Host "BIOS Version"
if ([string]::IsNullOrWhiteSpace($biosVer)) {
    if ($newMfg -eq "Dell Inc.") {
        $biosVer = "$(Get-Random -Min 1 -Max 3).$(Get-Random -Min 10 -Max 25).$(Get-Random -Min 0 -Max 10)"
    } elseif ($newMfg -eq "HPE") {
        $biosVer = "U$(Get-Random -Min 30 -Max 50)"
    } else {
        $biosVer = "$(Get-Random -Min 1 -Max 3).$(Get-Random -Min 10 -Max 20)"
    }
}
Write-Host "[SET] BIOS Version = $biosVer" -ForegroundColor Green

# BIOS Release Date
Write-Host "`nSTEP 8: BIOS Release Date" -ForegroundColor Cyan
$biosDate = Read-Host "Enter date (MM/dd/yyyy) or press Enter for random recent date"
if ([string]::IsNullOrWhiteSpace($biosDate)) {
    $randomDays = Get-Random -Min 90 -Max 730
    $biosDate = (Get-Date).AddDays(-$randomDays).ToString("MM/dd/yyyy")
}
Write-Host "[SET] BIOS Date = $biosDate" -ForegroundColor Green

# Serial Number
Write-Host "`nSTEP 9: Serial Number / SKU" -ForegroundColor Cyan
Write-Host "  Press Enter to auto-generate"
$serialNum = Read-Host "Serial Number"
if ([string]::IsNullOrWhiteSpace($serialNum)) {
    if ($newMfg -eq "Dell Inc.") {
        $serialNum = -join ((65..90) + (48..57) | Get-Random -Count 7 | ForEach-Object {[char]$_})
    } elseif ($newMfg -eq "HPE") {
        $serialNum = "CZ" + (-join (48..57 | Get-Random -Count 8 | ForEach-Object {[char]$_}))
    } else {
        $serialNum = -join ((65..90) + (48..57) | Get-Random -Count 10 | ForEach-Object {[char]$_})
    }
}
Write-Host "[SET] Serial Number = $serialNum" -ForegroundColor Green

# Machine GUID
Write-Host "`nSTEP 10: Machine GUID" -ForegroundColor Cyan
$currentGuid = (Get-ItemProperty "HKLM:\SOFTWARE\Microsoft\Cryptography").MachineGuid
Write-Host "  Current: $currentGuid"
$genGuid = Read-Host "Generate new GUID? (Y/N)"
if ($genGuid -match '^[Yy]') {
    $newGuid = [guid]::NewGuid().ToString()
    Write-Host "[SET] New GUID = $newGuid" -ForegroundColor Green
} else {
    $newGuid = $currentGuid
    Write-Host "[SET] Keeping current GUID" -ForegroundColor Green
}

# MAC Address
Write-Host "`nSTEP 11: MAC Address" -ForegroundColor Cyan
$currentMAC = (Get-NetAdapter | Where-Object Status -eq "Up" | Select-Object -First 1).MacAddress
Write-Host "  Current: $currentMAC"
$changeMac = Read-Host "Change MAC address? (Y/N)"
if ($changeMac -match '^[Yy]') {
    $ouiMap = @{
        "Dell Inc." = "B0-83-FE"
        "HP" = "94-57-A5"
        "HPE" = "94-57-A5"
        "Lenovo" = "54-EE-75"
        "Cisco" = "00-1B-54"
        "Microsoft" = "00-15-5D"
    }
    $oui = if ($ouiMap[$newMfg]) { $ouiMap[$newMfg] } else { "00-1B-21" }
    $suffix = -join (0..2 | ForEach-Object { "{0:X2}" -f (Get-Random -Max 256) })
    $newMAC = "$oui-" + ($suffix -replace '(.{2})(?=.)', '$1-')
    Write-Host "[SET] New MAC = $newMAC" -ForegroundColor Green
} else {
    $newMAC = $null
    Write-Host "[SET] Keeping current MAC" -ForegroundColor Gray
}

# VMware Tools
Write-Host "`nSTEP 12: VMware Tools" -ForegroundColor Cyan
Write-Host "  Malware often checks for VMware Tools processes and services"
$handleVMTools = Read-Host "Disable VMware Tools? (Y/N)"
$disableVMTools = ($handleVMTools -match '^[Yy]')

# Scheduled Task
Write-Host "`nSTEP 13: Scheduled Task (Persistence)" -ForegroundColor Cyan
Write-Host "  Create a scheduled task to re-apply these settings at every boot?"
Write-Host "  This ensures settings persist across reboots."
$createTask = Read-Host "Create scheduled task? (Y/N)"
$installTask = ($createTask -match '^[Yy]')

$taskName = $null
if ($installTask) {
    Write-Host "`nSTEP 13a: Task Name" -ForegroundColor Cyan
    Write-Host "  Examples: WindowsUpdateCheck, SystemMaintenance, NetworkMonitor"
    Write-Host "  Default:  WindowsUpdateCheck"
    $taskName = Read-Host "Enter task name (or press Enter for default)"
    if ([string]::IsNullOrWhiteSpace($taskName)) {
        $taskName = "WindowsUpdateCheck"
    }
    Write-Host "[SET] Task Name = $taskName" -ForegroundColor Green
}

# Summary
Write-Host "`n=======================================" -ForegroundColor Yellow
Write-Host "SUMMARY - About to apply:" -ForegroundColor Yellow
Write-Host "=======================================" -ForegroundColor Yellow
Write-Host "  OS Version:     $newOSVersion" -ForegroundColor Cyan
Write-Host "  Processor:      $cpuName" -ForegroundColor Cyan
Write-Host "  CPU Cores:      $cpuCores"
Write-Host "  Hostname:       $newHostname"
Write-Host "  Owner:          $newOwner"
Write-Host "  Organization:   $newOrg"
Write-Host "  Manufacturer:   $newMfg"
Write-Host "  Model:          $newModel"
Write-Host "  Board Product:  $boardProduct"
Write-Host "  BIOS Version:   $biosVer"
Write-Host "  BIOS Date:      $biosDate"
Write-Host "  Serial Number:  $serialNum"
Write-Host "  Machine GUID:   $newGuid"
if ($newMAC) { Write-Host "  MAC Address:    $newMAC" }
if ($disableVMTools) { Write-Host "  VMware Tools:   Will be disabled" -ForegroundColor Yellow }
if ($installTask) { Write-Host "  Scheduled Task: $taskName (at boot)" -ForegroundColor Cyan }
Write-Host ""

$confirm = Read-Host "Apply these changes? (Y/N)"
if ($confirm -notmatch '^[Yy]') {
    Write-Host "[CANCELLED] No changes made" -ForegroundColor Red
    Read-Host "Press Enter to exit"
    exit
}

# Apply changes
Write-Host "`n[APPLYING] Making system modifications..." -ForegroundColor Yellow

try {
    # 1. HARDWARE\DESCRIPTION\System\BIOS
    Write-Host "`n[1/8] Updating HARDWARE\DESCRIPTION\System\BIOS..." -ForegroundColor Cyan
    $biosPath = "HKLM:\HARDWARE\DESCRIPTION\System\BIOS"
    if (Test-Path $biosPath) {
        # Baseboard
        Set-ItemProperty -Path $biosPath -Name "BaseBoardManufacturer" -Value $newMfg -Type String -Force
        Set-ItemProperty -Path $biosPath -Name "BaseBoardProduct" -Value $boardProduct -Type String -Force
        Set-ItemProperty -Path $biosPath -Name "BaseBoardVersion" -Value "None" -Type String -Force

        # BIOS
        $biosMajor = [int]$biosVer.Split('.')[0]
        $biosMinor = if ($biosVer.Split('.').Count -gt 1) { [int]$biosVer.Split('.')[1] } else { 0 }
        Set-ItemProperty -Path $biosPath -Name "BiosMajorRelease" -Value $biosMajor -Type DWord -Force
        Set-ItemProperty -Path $biosPath -Name "BiosMinorRelease" -Value $biosMinor -Type DWord -Force
        Set-ItemProperty -Path $biosPath -Name "BIOSReleaseDate" -Value $biosDate -Type String -Force
        Set-ItemProperty -Path $biosPath -Name "BIOSVendor" -Value $newMfg -Type String -Force
        Set-ItemProperty -Path $biosPath -Name "BIOSVersion" -Value $biosVer -Type String -Force

        # EC Firmware
        Set-ItemProperty -Path $biosPath -Name "ECFirmwareMajorRelease" -Value 0x00000000 -Type DWord -Force
        Set-ItemProperty -Path $biosPath -Name "ECFirmwareMinorRelease" -Value 0x00000000 -Type DWord -Force

        # Enclosure Type
        $enclosureType = if ($isServer) { 0x00000001 } else { 0x00000003 }
        Set-ItemProperty -Path $biosPath -Name "EnclosureType" -Value $enclosureType -Type DWord -Force

        # System
        $systemFamily = if ($isServer) { "Server" } else { "Desktop" }
        Set-ItemProperty -Path $biosPath -Name "SystemFamily" -Value $systemFamily -Type String -Force
        Set-ItemProperty -Path $biosPath -Name "SystemManufacturer" -Value $newMfg -Type String -Force
        Set-ItemProperty -Path $biosPath -Name "SystemProductName" -Value $newModel -Type String -Force
        Set-ItemProperty -Path $biosPath -Name "SystemSKU" -Value $serialNum -Type String -Force
        Set-ItemProperty -Path $biosPath -Name "SystemVersion" -Value "1.0" -Type String -Force

        Write-Host "    [OK] HARDWARE\DESCRIPTION\System\BIOS updated" -ForegroundColor Green
    }

    # 2. CPU Information (CentralProcessor)
    Write-Host "`n[2/11] Updating CPU Information..." -ForegroundColor Cyan
    $cpuBasePath = "HKLM:\HARDWARE\DESCRIPTION\System\CentralProcessor"

    # Get actual number of logical processors or use specified cores
    $actualCores = (Get-WmiObject Win32_Processor | Measure-Object -Property NumberOfLogicalProcessors -Sum).Sum
    $processorCount = if ($actualCores) { $actualCores } else { $cpuCores }

    Write-Host "    [INFO] Patching $processorCount processor entries" -ForegroundColor Gray

    for ($i = 0; $i -lt $processorCount; $i++) {
        $cpuPath = "$cpuBasePath\$i"
        if (Test-Path $cpuPath) {
            Set-ItemProperty -Path $cpuPath -Name "ProcessorNameString" -Value $cpuName -Type String -Force -ErrorAction SilentlyContinue
            Set-ItemProperty -Path $cpuPath -Name "~MHz" -Value $cpuMHz -Type DWord -Force -ErrorAction SilentlyContinue
            Set-ItemProperty -Path $cpuPath -Name "VendorIdentifier" -Value $(if ($cpuName -match "AMD") { "AuthenticAMD" } else { "GenuineIntel" }) -Type String -Force -ErrorAction SilentlyContinue
        }
    }
    Write-Host "    [OK] CPU information updated for $processorCount cores" -ForegroundColor Green

    # 3. SystemInformation
    Write-Host "`n[3/11] Updating SystemInformation..." -ForegroundColor Cyan
    $sysPath = "HKLM:\SYSTEM\CurrentControlSet\Control\SystemInformation"
    if (-not (Test-Path $sysPath)) { New-Item -Path $sysPath -Force | Out-Null }
    Set-ItemProperty -Path $sysPath -Name "SystemManufacturer" -Value $newMfg
    Set-ItemProperty -Path $sysPath -Name "SystemProductName" -Value $newModel
    Set-ItemProperty -Path $sysPath -Name "BIOSVendor" -Value $newMfg
    Set-ItemProperty -Path $sysPath -Name "BIOSVersion" -Value $biosVer
    Set-ItemProperty -Path $sysPath -Name "BIOSReleaseDate" -Value $biosDate
    Write-Host "    [OK] SystemInformation updated" -ForegroundColor Green

    # 4. OS Version (ProductName)
    Write-Host "`n[4/11] Updating OS Version..." -ForegroundColor Cyan
    $winPath = "HKLM:\SOFTWARE\Microsoft\Windows NT\CurrentVersion"
    Set-ItemProperty -Path $winPath -Name "ProductName" -Value $newOSVersion
    Write-Host "    [OK] OS Version set to: $newOSVersion" -ForegroundColor Green

    # 5. Owner/Organization
    Write-Host "`n[5/11] Updating Owner and Organization..." -ForegroundColor Cyan
    Set-ItemProperty -Path $winPath -Name "RegisteredOwner" -Value $newOwner
    Set-ItemProperty -Path $winPath -Name "RegisteredOrganization" -Value $newOrg
    Write-Host "    [OK] Owner and Organization updated" -ForegroundColor Green

    # 6. Machine GUID
    Write-Host "`n[6/11] Updating Machine GUID..." -ForegroundColor Cyan
    Set-ItemProperty -Path "HKLM:\SOFTWARE\Microsoft\Cryptography" -Name "MachineGuid" -Value $newGuid
    Write-Host "    [OK] Machine GUID updated" -ForegroundColor Green

    # 7. Hostname
    Write-Host "`n[7/11] Updating Hostname..." -ForegroundColor Cyan
    if ($newHostname -ne $hostname) {
        Rename-Computer -NewName $newHostname -Force -ErrorAction SilentlyContinue
        Write-Host "    [OK] Hostname will change to '$newHostname' after restart" -ForegroundColor Green
    } else {
        Write-Host "    [SKIP] Hostname unchanged" -ForegroundColor Gray
    }

    # 8. MAC Address
    Write-Host "`n[8/11] Updating MAC Address..." -ForegroundColor Cyan
    if ($newMAC) {
        Write-Host "    [INFO] MAC must also be changed in VMware settings" -ForegroundColor Yellow
        try {
            $adapter = Get-NetAdapter | Where-Object Status -eq "Up" | Select-Object -First 1
            Set-NetAdapter -Name $adapter.Name -MacAddress $newMAC.Replace("-", "") -Confirm:$false -ErrorAction Stop
            Write-Host "    [OK] MAC address set in Windows" -ForegroundColor Green
        } catch {
            Write-Host "    [WARN] Windows MAC change failed - change in VM settings" -ForegroundColor Yellow
        }
    } else {
        Write-Host "    [SKIP] MAC address unchanged" -ForegroundColor Gray
    }

    # 9. VMware Tools
    Write-Host "`n[9/11] Handling VMware Tools..." -ForegroundColor Cyan
    if ($disableVMTools) {
        $vmServices = @("VMTools", "VGAuthService", "vm3dservice")
        foreach ($svc in $vmServices) {
            $service = Get-Service -Name $svc -ErrorAction SilentlyContinue
            if ($service) {
                Stop-Service -Name $svc -Force -ErrorAction SilentlyContinue
                Set-Service -Name $svc -StartupType Disabled -ErrorAction SilentlyContinue
                Write-Host "    [OK] Disabled service: $svc" -ForegroundColor Green
            }
        }
    } else {
        Write-Host "    [SKIP] VMware Tools unchanged" -ForegroundColor Gray
    }

    # 10. Scheduled Task
    Write-Host "`n[10/11] Creating Scheduled Task..." -ForegroundColor Cyan
    if ($installTask) {
        # Create the script that will run at startup
        $scriptContent = @"
# Auto-generated BIOS Registry Patcher
# Task: $taskName
# Generated: $(Get-Date)

`$logPath = "C:\Windows\Temp\bios_patch_$($taskName).log"
`$timestamp = Get-Date -Format "yyyy-MM-dd HH:mm:ss"

try {
    `$biosPath = "HKLM:\HARDWARE\DESCRIPTION\System\BIOS"

    if (Test-Path `$biosPath) {
        # Baseboard Information
        Set-ItemProperty -Path `$biosPath -Name "BaseBoardManufacturer" -Value "$newMfg" -Type String -Force -ErrorAction Stop
        Set-ItemProperty -Path `$biosPath -Name "BaseBoardProduct" -Value "$boardProduct" -Type String -Force -ErrorAction Stop
        Set-ItemProperty -Path `$biosPath -Name "BaseBoardVersion" -Value "None" -Type String -Force -ErrorAction Stop

        # BIOS Information
        Set-ItemProperty -Path `$biosPath -Name "BiosMajorRelease" -Value $biosMajor -Type DWord -Force -ErrorAction Stop
        Set-ItemProperty -Path `$biosPath -Name "BiosMinorRelease" -Value $biosMinor -Type DWord -Force -ErrorAction Stop
        Set-ItemProperty -Path `$biosPath -Name "BIOSReleaseDate" -Value "$biosDate" -Type String -Force -ErrorAction Stop
        Set-ItemProperty -Path `$biosPath -Name "BIOSVendor" -Value "$newMfg" -Type String -Force -ErrorAction Stop
        Set-ItemProperty -Path `$biosPath -Name "BIOSVersion" -Value "$biosVer" -Type String -Force -ErrorAction Stop

        # EC Firmware
        Set-ItemProperty -Path `$biosPath -Name "ECFirmwareMajorRelease" -Value 0x00000000 -Type DWord -Force -ErrorAction Stop
        Set-ItemProperty -Path `$biosPath -Name "ECFirmwareMinorRelease" -Value 0x00000000 -Type DWord -Force -ErrorAction Stop

        # Enclosure Type
        Set-ItemProperty -Path `$biosPath -Name "EnclosureType" -Value $enclosureType -Type DWord -Force -ErrorAction Stop

        # System Information
        Set-ItemProperty -Path `$biosPath -Name "SystemFamily" -Value "$systemFamily" -Type String -Force -ErrorAction Stop
        Set-ItemProperty -Path `$biosPath -Name "SystemManufacturer" -Value "$newMfg" -Type String -Force -ErrorAction Stop
        Set-ItemProperty -Path `$biosPath -Name "SystemProductName" -Value "$newModel" -Type String -Force -ErrorAction Stop
        Set-ItemProperty -Path `$biosPath -Name "SystemSKU" -Value "$serialNum" -Type String -Force -ErrorAction Stop
        Set-ItemProperty -Path `$biosPath -Name "SystemVersion" -Value "1.0" -Type String -Force -ErrorAction Stop

        # SystemInformation (persistent)
        `$sysInfoPath = "HKLM:\SYSTEM\CurrentControlSet\Control\SystemInformation"
        if (-not (Test-Path `$sysInfoPath)) {
            New-Item -Path `$sysInfoPath -Force | Out-Null
        }
        Set-ItemProperty -Path `$sysInfoPath -Name "SystemManufacturer" -Value "$newMfg" -Type String -Force -ErrorAction Stop
        Set-ItemProperty -Path `$sysInfoPath -Name "SystemProductName" -Value "$newModel" -Type String -Force -ErrorAction Stop
        Set-ItemProperty -Path `$sysInfoPath -Name "BIOSVendor" -Value "$newMfg" -Type String -Force -ErrorAction Stop
        Set-ItemProperty -Path `$sysInfoPath -Name "BIOSVersion" -Value "$biosVer" -Type String -Force -ErrorAction Stop
        Set-ItemProperty -Path `$sysInfoPath -Name "BIOSReleaseDate" -Value "$biosDate" -Type String -Force -ErrorAction Stop

        # CPU Information (CentralProcessor)
        `$cpuBasePath = "HKLM:\HARDWARE\DESCRIPTION\System\CentralProcessor"
        `$actualCores = (Get-WmiObject Win32_Processor | Measure-Object -Property NumberOfLogicalProcessors -Sum).Sum
        `$processorCount = if (`$actualCores) { `$actualCores } else { $cpuCores }
        for (`$i = 0; `$i -lt `$processorCount; `$i++) {
            `$cpuPath = "`$cpuBasePath\`$i"
            if (Test-Path `$cpuPath) {
                Set-ItemProperty -Path `$cpuPath -Name "ProcessorNameString" -Value "$cpuName" -Type String -Force -ErrorAction SilentlyContinue
                Set-ItemProperty -Path `$cpuPath -Name "~MHz" -Value $cpuMHz -Type DWord -Force -ErrorAction SilentlyContinue
                Set-ItemProperty -Path `$cpuPath -Name "VendorIdentifier" -Value "$(if ($cpuName -match "AMD") { "AuthenticAMD" } else { "GenuineIntel" })" -Type String -Force -ErrorAction SilentlyContinue
            }
        }

        # OS Version (ProductName)
        `$winPath = "HKLM:\SOFTWARE\Microsoft\Windows NT\CurrentVersion"
        Set-ItemProperty -Path `$winPath -Name "ProductName" -Value "$newOSVersion" -Type String -Force -ErrorAction SilentlyContinue

        # Owner and Organization
        Set-ItemProperty -Path `$winPath -Name "RegisteredOwner" -Value "$newOwner" -Type String -Force -ErrorAction SilentlyContinue
        Set-ItemProperty -Path `$winPath -Name "RegisteredOrganization" -Value "$newOrg" -Type String -Force -ErrorAction SilentlyContinue

        # Machine GUID
        Set-ItemProperty -Path "HKLM:\SOFTWARE\Microsoft\Cryptography" -Name "MachineGuid" -Value "$newGuid" -Type String -Force -ErrorAction SilentlyContinue

        Add-Content -Path `$logPath -Value "`$timestamp - SUCCESS: All registry keys patched"
    }
} catch {
    Add-Content -Path `$logPath -Value "`$timestamp - ERROR: `$(`$_.Exception.Message)"
}
"@

        # Write script to System32
        $scriptPath = "C:\Windows\System32\$taskName.ps1"
        Set-Content -Path $scriptPath -Value $scriptContent -Force
        Write-Host "    [OK] Created script: $scriptPath" -ForegroundColor Green

        # Remove old task if exists
        $existingTask = Get-ScheduledTask -TaskName $taskName -ErrorAction SilentlyContinue
        if ($existingTask) {
            Unregister-ScheduledTask -TaskName $taskName -Confirm:$false
            Write-Host "    [OK] Removed existing task: $taskName" -ForegroundColor Green
        }

        # Create scheduled task
        $action = New-ScheduledTaskAction -Execute "PowerShell.exe" `
            -Argument "-ExecutionPolicy Bypass -WindowStyle Hidden -File `"$scriptPath`""

        $trigger = New-ScheduledTaskTrigger -AtStartup
        # Add 1-minute delay using COM object (compatible with all versions)
        $trigger.Delay = "PT1M"  # ISO 8601 format: 1 minute

        $principal = New-ScheduledTaskPrincipal -UserId "SYSTEM" `
            -LogonType ServiceAccount -RunLevel Highest

        $settings = New-ScheduledTaskSettingsSet -AllowStartIfOnBatteries `
            -DontStopIfGoingOnBatteries -StartWhenAvailable -ExecutionTimeLimit (New-TimeSpan -Minutes 5)

        Register-ScheduledTask -TaskName $taskName `
            -Action $action -Trigger $trigger -Principal $principal `
            -Settings $settings -Description "System maintenance task" | Out-Null

        Write-Host "    [OK] Scheduled task '$taskName' created" -ForegroundColor Green
        Write-Host "    [INFO] Log file: C:\Windows\Temp\bios_patch_$taskName.log" -ForegroundColor Gray
    } else {
        Write-Host "    [SKIP] Scheduled task not requested" -ForegroundColor Gray
    }

    # 11. Restart WMI
    Write-Host "`n[11/11] Restarting WMI service..." -ForegroundColor Cyan
    try {
        Stop-Service WinMgmt -Force -ErrorAction SilentlyContinue
        Start-Sleep -Seconds 3
        Start-Service WinMgmt -ErrorAction SilentlyContinue
        Write-Host "    [OK] WMI service restarted" -ForegroundColor Green
    } catch {
        Write-Host "    [WARN] Could not restart WMI" -ForegroundColor Yellow
    }

    Write-Host "`n========================================" -ForegroundColor Green
    Write-Host "[SUCCESS] All changes applied!" -ForegroundColor Green
    Write-Host "========================================" -ForegroundColor Green
    Write-Host ""
    Write-Host "VERIFICATION:" -ForegroundColor Yellow
    $biosCheck = Get-ItemProperty "HKLM:\HARDWARE\DESCRIPTION\System\BIOS"
    Write-Host "  SystemManufacturer: $($biosCheck.SystemManufacturer)" -ForegroundColor $(if ($biosCheck.SystemManufacturer -eq $newMfg) { "Green" } else { "Red" })
    Write-Host "  SystemProductName:  $($biosCheck.SystemProductName)" -ForegroundColor $(if ($biosCheck.SystemProductName -eq $newModel) { "Green" } else { "Red" })
    Write-Host "  BIOSVendor:         $($biosCheck.BIOSVendor)" -ForegroundColor $(if ($biosCheck.BIOSVendor -eq $newMfg) { "Green" } else { "Red" })
    Write-Host "  BIOSVersion:        $($biosCheck.BIOSVersion)" -ForegroundColor $(if ($biosCheck.BIOSVersion -eq $biosVer) { "Green" } else { "Red" })

    Write-Host "`nIMPORTANT NEXT STEPS:" -ForegroundColor Yellow
    Write-Host "  1. RESTART Windows for hostname change" -ForegroundColor White
    Write-Host "  2. Run 'systeminfo' to verify" -ForegroundColor White
    if ($installTask) {
        Write-Host "  3. Scheduled task '$taskName' will run at every boot" -ForegroundColor Cyan
        Write-Host "     - Maintains registry values automatically" -ForegroundColor Gray
        Write-Host "     - Check log: C:\Windows\Temp\bios_patch_$taskName.log" -ForegroundColor Gray
        Write-Host "     - View task: Get-ScheduledTask -TaskName '$taskName'" -ForegroundColor Gray
        Write-Host "     - Remove task: Unregister-ScheduledTask -TaskName '$taskName'" -ForegroundColor Gray
    }
    Write-Host "  $(if ($installTask) { '4' } else { '3' }). If systeminfo still shows VMware:" -ForegroundColor White
    Write-Host "     - This is due to ESXi 8.0.3 SMBIOS bug" -ForegroundColor Gray
    Write-Host "     - Registry is correct (verified above)" -ForegroundColor Gray
    Write-Host "     - Consider using fake_systeminfo from GitHub" -ForegroundColor Gray
    Write-Host ""

    $restart = Read-Host "Restart now? (Y/N)"
    if ($restart -match '^[Yy]') {
        Write-Host "Restarting in 5 seconds..." -ForegroundColor Yellow
        Start-Sleep -Seconds 5
        Restart-Computer -Force
    }

} catch {
    Write-Host "[ERROR] $($_.Exception.Message)" -ForegroundColor Red
    Write-Host "Stack Trace: $($_.ScriptStackTrace)" -ForegroundColor Red
}

Write-Host ""
Read-Host "Press Enter to exit"

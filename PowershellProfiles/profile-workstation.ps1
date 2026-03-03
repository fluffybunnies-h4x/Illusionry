# profile.ps1 for Windows 11 Workstations
# WMI Hook Script for VM Evasion with Unique Hardware IDs
# Deploy to: C:\Windows\System32\WindowsPowerShell\v1.0\profile.ps1

#region Generate and Store Unique Hardware IDs

# Registry location to store persistent unique IDs
$regPath = "HKLM:\SOFTWARE\QUANTUMHardware"

# Check if running as admin
$isAdmin = ([Security.Principal.WindowsPrincipal] [Security.Principal.WindowsIdentity]::GetCurrent()).IsInRole([Security.Principal.WindowsBuiltInRole]::Administrator)

# Only try to create/write if we're admin
if ($isAdmin) {
    # Create registry key if it doesn't exist
    if (!(Test-Path $regPath)) {
        try {
            New-Item -Path $regPath -Force | Out-Null
        } catch {
            # Silently fail if we can't create it
        }
    }
}

# Function to generate Dell-style service tag (7 characters)
function New-DellServiceTag {
    $chars = "0123456789BCDFGHJKLMNPQRSTVWXYZ" # Dell uses base-32 without vowels
    $tag = ""
    for ($i = 0; $i -lt 7; $i++) {
        $tag += $chars[(Get-Random -Maximum $chars.Length)]
    }
    return $tag
}

# Function to generate Dell-style serial number
function New-DellSerialNumber {
    param([string]$ServiceTag)
    # Dell format: CN0 + 4 chars + service tag
    $chars = "0123456789BCDFGHJKLMNPQRSTVWXYZ"
    $middle = ""
    for ($i = 0; $i -lt 4; $i++) {
        $middle += $chars[(Get-Random -Maximum $chars.Length)]
    }
    return "CN0${middle}${ServiceTag}"
}

# Function to generate Dell-style UUID
function New-DellUUID {
    param([string]$ServiceTag)
    # Dell UUID starts with 44454C4C (DELL in hex)
    # Convert service tag to hex and use in UUID
    $tagBytes = [System.Text.Encoding]::ASCII.GetBytes($ServiceTag)
    $tagHex = [System.BitConverter]::ToString($tagBytes).Replace("-","")
    
    # Pad with random hex to fit UUID format
    while ($tagHex.Length -lt 24) {
        $tagHex += (Get-Random -Maximum 256).ToString("X2")
    }
    
    # Format as Dell UUID: 44454C4C-XXXX-XXXX-XXXX-XXXXXXXXXXXX
    $uuid = "44454C4C-" + $tagHex.Substring(0,4) + "-" + $tagHex.Substring(4,4) + "-" + $tagHex.Substring(8,4) + "-" + $tagHex.Substring(12,12)
    return $uuid.ToUpper()
}

# Function to generate disk serial number
function New-DiskSerialNumber {
    $serial = ""
    for ($i = 0; $i -lt 20; $i++) {
        $serial += (Get-Random -Maximum 10).ToString()
    }
    return $serial
}

# Try to read from registry, with fallback to generating new values
$script:ServiceTag = $null
$script:SerialNumber = $null
$script:SystemUUID = $null
$script:DiskSerial = $null

# Try to read existing values
try {
    $script:ServiceTag = Get-ItemProperty -Path $regPath -Name "ServiceTag" -ErrorAction SilentlyContinue | Select-Object -ExpandProperty ServiceTag
    $script:SerialNumber = Get-ItemProperty -Path $regPath -Name "SerialNumber" -ErrorAction SilentlyContinue | Select-Object -ExpandProperty SerialNumber
    $script:SystemUUID = Get-ItemProperty -Path $regPath -Name "SystemUUID" -ErrorAction SilentlyContinue | Select-Object -ExpandProperty SystemUUID
    $script:DiskSerial = Get-ItemProperty -Path $regPath -Name "DiskSerial" -ErrorAction SilentlyContinue | Select-Object -ExpandProperty DiskSerial
} catch {
    # Registry doesn't exist yet or we can't read it
}

# Generate new values if they don't exist
if (!$script:ServiceTag) {
    $script:ServiceTag = New-DellServiceTag
    if ($isAdmin -and (Test-Path $regPath)) {
        try { Set-ItemProperty -Path $regPath -Name "ServiceTag" -Value $script:ServiceTag -ErrorAction SilentlyContinue } catch {}
    }
}

if (!$script:SerialNumber) {
    $script:SerialNumber = New-DellSerialNumber -ServiceTag $script:ServiceTag
    if ($isAdmin -and (Test-Path $regPath)) {
        try { Set-ItemProperty -Path $regPath -Name "SerialNumber" -Value $script:SerialNumber -ErrorAction SilentlyContinue } catch {}
    }
}

if (!$script:SystemUUID) {
    $script:SystemUUID = New-DellUUID -ServiceTag $script:ServiceTag
    if ($isAdmin -and (Test-Path $regPath)) {
        try { Set-ItemProperty -Path $regPath -Name "SystemUUID" -Value $script:SystemUUID -ErrorAction SilentlyContinue } catch {}
    }
}

if (!$script:DiskSerial) {
    $script:DiskSerial = New-DiskSerialNumber
    if ($isAdmin -and (Test-Path $regPath)) {
        try { Set-ItemProperty -Path $regPath -Name "DiskSerial" -Value $script:DiskSerial -ErrorAction SilentlyContinue } catch {}
    }
}

#endregion

#region Read System Configuration from Registry

# Read BIOS/System info from registry (set by your registry configuration)
function Get-RegistryValue {
    param(
        [string]$Path,
        [string]$Name,
        [string]$Default = ""
    )
    
    try {
        $value = Get-ItemProperty -Path $Path -Name $Name -ErrorAction SilentlyContinue | Select-Object -ExpandProperty $Name
        if ($value) {
            return $value
        }
    } catch {
        # Ignore errors
    }
    return $Default
}

$biosRegPath = "HKLM:\HARDWARE\DESCRIPTION\System\BIOS"

# Read system configuration from registry - WORKSTATION DEFAULTS
$script:SystemManufacturer = Get-RegistryValue -Path $biosRegPath -Name "SystemManufacturer" -Default "Dell Inc."
$script:SystemProductName = Get-RegistryValue -Path $biosRegPath -Name "SystemProductName" -Default "Latitude 5540"
$script:BIOSVendor = Get-RegistryValue -Path $biosRegPath -Name "BIOSVendor" -Default "Dell Inc."
$script:BIOSVersion = Get-RegistryValue -Path $biosRegPath -Name "BIOSVersion" -Default "1.8.1"
$script:BIOSReleaseDate = Get-RegistryValue -Path $biosRegPath -Name "BIOSReleaseDate" -Default "10/27/2025"
$script:BaseBoardManufacturer = Get-RegistryValue -Path $biosRegPath -Name "BaseBoardManufacturer" -Default "Dell Inc."
$script:BaseBoardProduct = Get-RegistryValue -Path $biosRegPath -Name "BaseBoardProduct" -Default "0G9MWF"

# Convert date format for WMI (MM/DD/YYYY -> YYYYMMDD000000.000000+000)
if ($script:BIOSReleaseDate -match "(\d{2})/(\d{2})/(\d{4})") {
    $script:BIOSReleaseDateWMI = "$($Matches[3])$($Matches[1])$($Matches[2])000000.000000+000"
} else {
    $script:BIOSReleaseDateWMI = "20251027000000.000000+000"
}

# Parse version for SMBIOS fields
if ($script:BIOSVersion -match "(\d+)\.(\d+)") {
    $script:SMBIOSMajorVersion = [int]$Matches[1]
    $script:SMBIOSMinorVersion = [int]$Matches[2]
} else {
    $script:SMBIOSMajorVersion = 1
    $script:SMBIOSMinorVersion = 8
}

# Build BIOS version strings
$script:BIOSVersionFull = "$($script:BIOSVendor)   - $($script:BIOSVersion)"
$script:BIOSVersionArray = @("$($script:BIOSVendor)   - $($script:BIOSVersion)", $script:BIOSVersion, "American Megatrends - 5000B")

#endregion

#region Get-WmiObject Hook

# Store the original cmdlet reference BEFORE removing it
$script:OriginalGetWmiObject = Get-Command Get-WmiObject -CommandType Cmdlet

# Remove the cmdlet from the session
Remove-Item -Path Function:\Get-WmiObject -Force -ErrorAction SilentlyContinue

# Create our replacement function
function global:Get-WmiObject {
    [CmdletBinding()]
    param(
        [Parameter(ValueFromPipeline=$true)]
        [string]$Class,
        [string]$Query,
        [string]$Namespace = "root\cimv2",
        [string]$ComputerName = ".",
        [PSCredential]$Credential,
        [switch]$List
    )
    
    # Intercept Win32_BIOS queries
    if ($Class -eq "Win32_BIOS" -or $Query -like "*Win32_BIOS*") {
        return [PSCustomObject]@{
            PSComputerName = $env:COMPUTERNAME
            __GENUS = 2
            __CLASS = "Win32_BIOS"
            __SUPERCLASS = "CIM_BIOSElement"
            __DYNASTY = "CIM_ManagedSystemElement"
            __RELPATH = "Win32_BIOS.Name=`"$($script:BIOSVersion)`",SoftwareElementID=`"$($script:BIOSVersion)`",SoftwareElementState=3,TargetOperatingSystem=0,Version=`"$($script:BIOSVersionFull)`""
            __PROPERTY_COUNT = 27
            __DERIVATION = @("CIM_BIOSElement", "CIM_SoftwareElement", "CIM_LogicalElement", "CIM_ManagedSystemElement")
            __SERVER = $env:COMPUTERNAME
            __NAMESPACE = "root\cimv2"
            __PATH = "\\$env:COMPUTERNAME\root\cimv2:Win32_BIOS.Name=`"$($script:BIOSVersion)`",SoftwareElementID=`"$($script:BIOSVersion)`",SoftwareElementState=3,TargetOperatingSystem=0,Version=`"$($script:BIOSVersionFull)`""
            BiosCharacteristics = @(4, 7, 9, 11, 12, 15, 16, 19, 23, 24, 25, 26, 27, 28, 29, 32, 33, 40, 42, 43)
            BIOSVersion = $script:BIOSVersionArray
            BuildNumber = $null
            Caption = $script:BIOSVersion
            CodeSet = $null
            CurrentLanguage = "en|US|iso8859-1"
            Description = $script:BIOSVersion
            IdentificationCode = $null
            InstallableLanguages = 1
            InstallDate = $null
            LanguageEdition = $null
            ListOfLanguages = @("en|US|iso8859-1")
            Manufacturer = $script:BIOSVendor
            Name = $script:BIOSVersion
            OtherTargetOS = $null
            PrimaryBIOS = $true
            ReleaseDate = $script:BIOSReleaseDateWMI
            SerialNumber = $script:SerialNumber
            SMBIOSBIOSVersion = $script:BIOSVersion
            SMBIOSMajorVersion = $script:SMBIOSMajorVersion
            SMBIOSMinorVersion = $script:SMBIOSMinorVersion
            SMBIOSPresent = $true
            SoftwareElementID = $script:BIOSVersion
            SoftwareElementState = 3
            Status = "OK"
            TargetOperatingSystem = 0
            Version = $script:BIOSVersionFull
        }
    }
    
    # Intercept Win32_ComputerSystemProduct queries
    if ($Class -eq "Win32_ComputerSystemProduct" -or $Query -like "*ComputerSystemProduct*") {
        return [PSCustomObject]@{
            PSComputerName = $env:COMPUTERNAME
            __GENUS = 2
            __CLASS = "Win32_ComputerSystemProduct"
            __SUPERCLASS = "CIM_Product"
            __DYNASTY = "CIM_ManagedSystemElement"
            __RELPATH = "Win32_ComputerSystemProduct.IdentifyingNumber=`"$($script:SerialNumber)`",Name=`"$($script:SystemProductName)`",Version=`"Not Specified`""
            __PROPERTY_COUNT = 8
            __DERIVATION = @("CIM_Product", "CIM_ManagedSystemElement")
            __SERVER = $env:COMPUTERNAME
            __NAMESPACE = "root\cimv2"
            __PATH = "\\$env:COMPUTERNAME\root\cimv2:Win32_ComputerSystemProduct.IdentifyingNumber=`"$($script:SerialNumber)`",Name=`"$($script:SystemProductName)`",Version=`"Not Specified`""
            Caption = "Computer System Product"
            Description = "Computer System Product"
            IdentifyingNumber = $script:SerialNumber
            Name = $script:SystemProductName
            SKUNumber = $null
            UUID = $script:SystemUUID
            Vendor = $script:SystemManufacturer
            Version = "Not Specified"
        }
    }
    
    # Intercept Win32_DiskDrive queries
    if ($Class -eq "Win32_DiskDrive" -or $Query -like "*Win32_DiskDrive*") {
        # Call original cmdlet
        $realDisks = & $script:OriginalGetWmiObject -Class Win32_DiskDrive -Namespace $Namespace
        
        # Spoof VMware disks to look like NVMe SSD (common in modern laptops)
        foreach ($disk in $realDisks) {
            if ($disk.Model -match "VMware|VBOX|QEMU|Virtual|Xen|Microsoft Virtual Disk") {
                $disk.Model = "SAMSUNG MZVL2512HCJQ-00B00"
                $disk.Caption = "SAMSUNG MZVL2512HCJQ-00B00"
                $disk.SerialNumber = $script:DiskSerial
                $disk.InterfaceType = "NVMe"
                $disk.MediaType = "Fixed hard disk media"
            }
        }
        
        return $realDisks
    }
    
    # Intercept Win32_BaseBoard queries
    if ($Class -eq "Win32_BaseBoard" -or $Query -like "*Win32_BaseBoard*") {
        return [PSCustomObject]@{
            PSComputerName = $env:COMPUTERNAME
            __GENUS = 2
            __CLASS = "Win32_BaseBoard"
            __SUPERCLASS = "CIM_Card"
            __DYNASTY = "CIM_ManagedSystemElement"
            __RELPATH = "Win32_BaseBoard.Tag=`"Base Board`""
            __PROPERTY_COUNT = 26
            __DERIVATION = @("CIM_Card", "CIM_PhysicalPackage", "CIM_PhysicalElement", "CIM_ManagedSystemElement")
            __SERVER = $env:COMPUTERNAME
            __NAMESPACE = "root\cimv2"
            __PATH = "\\$env:COMPUTERNAME\root\cimv2:Win32_BaseBoard.Tag=`"Base Board`""
            Caption = "Base Board"
            ConfigOptions = $null
            CreationClassName = "Win32_BaseBoard"
            Depth = $null
            Description = "Base Board"
            Height = $null
            HostingBoard = $true
            HotSwappable = $false
            InstallDate = $null
            Manufacturer = $script:BaseBoardManufacturer
            Model = $null
            Name = "Base Board"
            OtherIdentifyingInfo = $null
            PartNumber = $null
            PoweredOn = $true
            Product = $script:BaseBoardProduct
            Removable = $false
            Replaceable = $true
            RequirementsDescription = $null
            RequiresDaughterBoard = $false
            SerialNumber = $script:SerialNumber
            SKU = $null
            SlotLayout = $null
            SpecialRequirements = $null
            Status = "OK"
            Tag = "Base Board"
            Version = "A00"
            Weight = $null
            Width = $null
        }
    }
    
    # Intercept Win32_NetworkAdapter queries
    if ($Class -eq "Win32_NetworkAdapter" -or $Query -like "*Win32_NetworkAdapter*") {
        $realAdapters = & $script:OriginalGetWmiObject -Class Win32_NetworkAdapter -Namespace $Namespace
        
        foreach ($adapter in $realAdapters) {
            if ($adapter.Name -match "VMware|vmxnet|Virtual") {
                $adapter.Name = "Intel(R) Wi-Fi 6E AX211 160MHz"
                $adapter.Description = "Intel(R) Wi-Fi 6E AX211 160MHz"
                $adapter.Manufacturer = "Intel Corporation"
                $adapter.ProductName = "Intel(R) Wi-Fi 6E AX211 160MHz"
            }
        }
        
        return $realAdapters
    }
    
    # Intercept Win32_NetworkAdapterConfiguration queries
    if ($Class -eq "Win32_NetworkAdapterConfiguration" -or $Query -like "*NetworkAdapterConfiguration*") {
        $realConfigs = & $script:OriginalGetWmiObject -Class Win32_NetworkAdapterConfiguration -Namespace $Namespace
        
        foreach ($config in $realConfigs) {
            if ($config.Description -match "VMware|vmxnet|Virtual") {
                $config.Description = "Intel(R) Wi-Fi 6E AX211 160MHz"
                $config.ServiceName = "Netwtw10"
            }
        }
        
        return $realConfigs
    }
    
    # Intercept Win32_ComputerSystem queries
    if ($Class -eq "Win32_ComputerSystem" -or $Query -like "*Win32_ComputerSystem*") {
        $realData = & $script:OriginalGetWmiObject -Class Win32_ComputerSystem -Namespace $Namespace
        $realData.Manufacturer = $script:SystemManufacturer
        $realData.Model = $script:SystemProductName
        return $realData
    }
    
    # Intercept Win32_VideoController queries
    if ($Class -eq "Win32_VideoController" -or $Query -like "*Win32_VideoController*") {
        $realVideo = & $script:OriginalGetWmiObject -Class Win32_VideoController -Namespace $Namespace
        
        if ($realVideo.Name -match "VMware|SVGA") {
            $realVideo.Name = "Intel(R) Iris(R) Xe Graphics"
            $realVideo.Description = "Intel(R) Iris(R) Xe Graphics"
            $realVideo.VideoProcessor = "Intel(R) Iris(R) Xe Graphics Family"
            $realVideo.AdapterCompatibility = "Intel Corporation"
        }
        
        return $realVideo
    }
    
    # Intercept Win32_IDEController queries
    if ($Class -eq "Win32_IDEController" -or $Query -like "*IDEController*") {
        $realIDE = & $script:OriginalGetWmiObject -Class Win32_IDEController -Namespace $Namespace
        
        foreach ($ide in $realIDE) {
            if ($ide.Name -match "VMware|Virtual") {
                $ide.Name = "Intel(R) Chipset SATA/PCIe RST Premium Controller"
                $ide.Manufacturer = "Intel Corporation"
            }
        }
        
        return $realIDE
    }
    
    # Intercept Win32_SCSIController queries
    if ($Class -eq "Win32_SCSIController" -or $Query -like "*SCSIController*") {
        $realSCSI = & $script:OriginalGetWmiObject -Class Win32_SCSIController -Namespace $Namespace
        
        foreach ($scsi in $realSCSI) {
            if ($scsi.Name -match "VMware|Virtual") {
                $scsi.Name = "Standard NVM Express Controller"
                $scsi.Manufacturer = "Standard NVM Express Controller"
                $scsi.Description = "Standard NVM Express Controller"
            }
        }
        
        return $realSCSI
    }
    
    # Pass everything else to original cmdlet
    & $script:OriginalGetWmiObject @PSBoundParameters
}

#endregion

#region Get-CimInstance Hook

# Store the original cmdlet reference
$script:OriginalGetCimInstance = Get-Command Get-CimInstance -CommandType Cmdlet -ErrorAction SilentlyContinue

if ($script:OriginalGetCimInstance) {
    # Remove the cmdlet from the session
    Remove-Item -Path Function:\Get-CimInstance -Force -ErrorAction SilentlyContinue
    
    # Create our replacement function
    function global:Get-CimInstance {
        [CmdletBinding()]
        param(
            [Parameter(ValueFromPipeline=$true)]
            [string]$ClassName,
            [string]$Query,
            [string]$Namespace = "root\cimv2",
            [string]$ComputerName = ".",
            [PSCredential]$Credential
        )
        
        # Route through our hooked Get-WmiObject
        if ($ClassName) {
            return Get-WmiObject -Class $ClassName -Namespace $Namespace
        }
        
        if ($Query) {
            return Get-WmiObject -Query $Query -Namespace $Namespace
        }
        
        # Pass through
        & $script:OriginalGetCimInstance @PSBoundParameters
    }
}

#endregion

#region Handle Read-Only Aliases

# Try to set aliases, but don't fail if they're already read-only
try {
    Remove-Item Alias:\gwmi -Force -ErrorAction SilentlyContinue
    Set-Alias -Name gwmi -Value Get-WmiObject -Scope Global -Option AllScope -ErrorAction SilentlyContinue
} catch {
    # Alias already exists and is read-only - that's fine
}

try {
    Remove-Item Alias:\gcim -Force -ErrorAction SilentlyContinue
    Set-Alias -Name gcim -Value Get-CimInstance -Scope Global -Option AllScope -ErrorAction SilentlyContinue
} catch {
    # Alias already exists and is read-only - that's fine
}

#endregion

# Success indicator (optional - uncomment to see what's loaded)
# Write-Host "WMI Hooks Loaded - Dell workstation spoofing active" -ForegroundColor Green
# Write-Host "  System: $($script:SystemManufacturer) $($script:SystemProductName)" -ForegroundColor Cyan
# Write-Host "  BIOS: $($script:BIOSVendor) $($script:BIOSVersion)" -ForegroundColor Cyan
# Write-Host "  Service Tag: $($script:ServiceTag)" -ForegroundColor Cyan
# Write-Host "  Serial Number: $($script:SerialNumber)" -ForegroundColor Cyan
# Write-Host "  UUID: $($script:SystemUUID)" -ForegroundColor Cyan
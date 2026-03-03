#include <windows.h>
#include <stdio.h>
#include <string.h>

// Compile command
// cl.exe /O2 /Fe:wmic.exe fake_wmic.c /link /SUBSYSTEM:CONSOLE advapi32.lib

// Helper function to check if a string contains a substring (case-insensitive)
int stristr_check(const char* haystack, const char* needle) {
    char h_lower[1024], n_lower[256];
    int i;
    
    // Convert to lowercase for comparison
    for (i = 0; haystack[i] && i < 1023; i++) {
        h_lower[i] = tolower(haystack[i]);
    }
    h_lower[i] = '\0';
    
    for (i = 0; needle[i] && i < 255; i++) {
        n_lower[i] = tolower(needle[i]);
    }
    n_lower[i] = '\0';
    
    return strstr(h_lower, n_lower) != NULL;
}

// Read registry value
void GetRegistryValue(HKEY hKey, const char* subKey, const char* valueName, char* output, size_t size) {
    HKEY hOpenKey;
    DWORD dwType = REG_SZ;
    DWORD dwSize = (DWORD)size;
    
    if (RegOpenKeyExA(hKey, subKey, 0, KEY_READ | KEY_WOW64_64KEY, &hOpenKey) == ERROR_SUCCESS) {
        if (RegQueryValueExA(hOpenKey, valueName, NULL, &dwType, (LPBYTE)output, &dwSize) != ERROR_SUCCESS) {
            output[0] = '\0';
        }
        RegCloseKey(hOpenKey);
    } else {
        output[0] = '\0';
    }
}

// Get unique IDs from VMEvasion registry
void GetUniqueIDs(char* serialNumber, char* uuid, char* diskSerial, size_t size) {
    GetRegistryValue(HKEY_LOCAL_MACHINE, "SOFTWARE\\VMEvasion", "SerialNumber", serialNumber, size);
    GetRegistryValue(HKEY_LOCAL_MACHINE, "SOFTWARE\\VMEvasion", "SystemUUID", uuid, size);
    GetRegistryValue(HKEY_LOCAL_MACHINE, "SOFTWARE\\VMEvasion", "DiskSerial", diskSerial, size);
}

int main(int argc, char* argv[]) {
    char cmdline[4096] = "";
    int i;
    
    // Build command line from arguments
    for (i = 1; i < argc; i++) {
        strcat(cmdline, argv[i]);
        strcat(cmdline, " ");
    }
    
    // Convert to lowercase for easier matching
    char cmdline_lower[4096];
    for (i = 0; cmdline[i] && i < 4095; i++) {
        cmdline_lower[i] = tolower(cmdline[i]);
    }
    cmdline_lower[i] = '\0';
    
    // Get BIOS/System info from registry
    char systemManufacturer[256] = {0};
    char systemProductName[256] = {0};
    char biosVendor[256] = {0};
    char biosVersion[256] = {0};
    char baseBoardProduct[256] = {0};
    
    GetRegistryValue(HKEY_LOCAL_MACHINE, "HARDWARE\\DESCRIPTION\\System\\BIOS", 
                     "SystemManufacturer", systemManufacturer, sizeof(systemManufacturer));
    GetRegistryValue(HKEY_LOCAL_MACHINE, "HARDWARE\\DESCRIPTION\\System\\BIOS",
                     "SystemProductName", systemProductName, sizeof(systemProductName));
    GetRegistryValue(HKEY_LOCAL_MACHINE, "HARDWARE\\DESCRIPTION\\System\\BIOS",
                     "BIOSVendor", biosVendor, sizeof(biosVendor));
    GetRegistryValue(HKEY_LOCAL_MACHINE, "HARDWARE\\DESCRIPTION\\System\\BIOS",
                     "BIOSVersion", biosVersion, sizeof(biosVersion));
    GetRegistryValue(HKEY_LOCAL_MACHINE, "HARDWARE\\DESCRIPTION\\System\\BIOS",
                     "BaseBoardProduct", baseBoardProduct, sizeof(baseBoardProduct));
    
    // Get unique IDs
    char serialNumber[256] = {0};
    char systemUUID[256] = {0};
    char diskSerial[256] = {0};
    GetUniqueIDs(serialNumber, systemUUID, diskSerial, sizeof(serialNumber));
    
    // Set defaults if registry is empty
    if (!strlen(systemManufacturer)) strcpy(systemManufacturer, "Dell Inc.");
    if (!strlen(systemProductName)) strcpy(systemProductName, "Latitude 5540");
    if (!strlen(biosVendor)) strcpy(biosVendor, "Dell Inc.");
    if (!strlen(biosVersion)) strcpy(biosVersion, "1.8.1");
    if (!strlen(baseBoardProduct)) strcpy(baseBoardProduct, "0G9MWF");
    if (!strlen(serialNumber)) strcpy(serialNumber, "CN0ABCD1234567");
    if (!strlen(systemUUID)) strcpy(systemUUID, "44454C4C-1234-5678-90AB-CDEF12345678");
    if (!strlen(diskSerial)) strcpy(diskSerial, "12345678901234567890");
    
    // Intercept BIOS queries
    if (stristr_check(cmdline_lower, "bios") && stristr_check(cmdline_lower, "manufacturer")) {
        printf("Manufacturer\n%s\n", biosVendor);
        return 0;
    }
    
    if (stristr_check(cmdline_lower, "bios") && stristr_check(cmdline_lower, "serialnumber")) {
        printf("SerialNumber\n%s\n", serialNumber);
        return 0;
    }
    
    if (stristr_check(cmdline_lower, "bios") && stristr_check(cmdline_lower, "version")) {
        printf("Version\n%s\n", biosVersion);
        return 0;
    }
    
    if (stristr_check(cmdline_lower, "bios") && stristr_check(cmdline_lower, "smbiosbiosversion")) {
        printf("SMBIOSBIOSVersion\n%s\n", biosVersion);
        return 0;
    }
    
    // Intercept ComputerSystem queries
    if (stristr_check(cmdline_lower, "computersystem") && stristr_check(cmdline_lower, "manufacturer")) {
        printf("Manufacturer\n%s\n", systemManufacturer);
        return 0;
    }
    
    if (stristr_check(cmdline_lower, "computersystem") && stristr_check(cmdline_lower, "model")) {
        printf("Model\n%s\n", systemProductName);
        return 0;
    }
    
    // Intercept CSProduct (UUID) queries
    if (stristr_check(cmdline_lower, "csproduct") && stristr_check(cmdline_lower, "name")) {
        printf("Name\n%s\n", systemProductName);
        return 0;
    }
    
    if (stristr_check(cmdline_lower, "csproduct") && stristr_check(cmdline_lower, "vendor")) {
        printf("Vendor\n%s\n", systemManufacturer);
        return 0;
    }
    
    if (stristr_check(cmdline_lower, "csproduct") && stristr_check(cmdline_lower, "uuid")) {
        printf("UUID\n%s\n", systemUUID);
        return 0;
    }
    
    if (stristr_check(cmdline_lower, "csproduct") && stristr_check(cmdline_lower, "identifyingnumber")) {
        printf("IdentifyingNumber\n%s\n", serialNumber);
        return 0;
    }
    
    // Intercept DiskDrive queries
    if (stristr_check(cmdline_lower, "diskdrive") && stristr_check(cmdline_lower, "model")) {
        printf("Model\nSAMSUNG MZVL2512HCJQ-00B00\n");
        return 0;
    }
    
    if (stristr_check(cmdline_lower, "diskdrive") && stristr_check(cmdline_lower, "serialnumber")) {
        printf("SerialNumber\n%s\n", diskSerial);
        return 0;
    }
    
    if (stristr_check(cmdline_lower, "diskdrive") && stristr_check(cmdline_lower, "caption")) {
        printf("Caption\nSAMSUNG MZVL2512HCJQ-00B00\n");
        return 0;
    }
    
    // Intercept BaseBoard queries
    if (stristr_check(cmdline_lower, "baseboard") && stristr_check(cmdline_lower, "manufacturer")) {
        printf("Manufacturer\n%s\n", systemManufacturer);
        return 0;
    }
    
    if (stristr_check(cmdline_lower, "baseboard") && stristr_check(cmdline_lower, "product")) {
        printf("Product\n%s\n", baseBoardProduct);
        return 0;
    }
    
    if (stristr_check(cmdline_lower, "baseboard") && stristr_check(cmdline_lower, "serialnumber")) {
        printf("SerialNumber\n%s\n", serialNumber);
        return 0;
    }
    
    // Intercept NIC queries
    if ((stristr_check(cmdline_lower, "nic") || stristr_check(cmdline_lower, "nicconfig")) && 
        (stristr_check(cmdline_lower, "name") || stristr_check(cmdline_lower, "description"))) {
        printf("Name\nIntel(R) Wi-Fi 6E AX211 160MHz\n");
        return 0;
    }
    
    // Intercept VideoController queries
    if (stristr_check(cmdline_lower, "videocontroller") && stristr_check(cmdline_lower, "name")) {
        printf("Name\nIntel(R) Iris(R) Xe Graphics\n");
        return 0;
    }
    
    // For everything else, call the real wmic
    char realWmicPath[MAX_PATH];
    strcpy(realWmicPath, "C:\\Windows\\System32\\wbem\\wmic.exe.bak ");
    strcat(realWmicPath, cmdline);
    
    return system(realWmicPath);
}
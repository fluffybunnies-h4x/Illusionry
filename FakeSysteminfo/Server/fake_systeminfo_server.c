#include <winsock2.h>
#include <ws2tcpip.h>
#include <windows.h>
#include <iphlpapi.h>
#include <stdio.h>
#include <time.h>
#include <stdlib.h>

#pragma comment(lib, "iphlpapi.lib")
#pragma comment(lib, "advapi32.lib")
#pragma comment(lib, "ws2_32.lib")

void GetRegistryValue(HKEY hKey, const char* subKey, const char* valueName, char* output, size_t size) {
    HKEY hOpenKey;
    DWORD dwType = REG_SZ;
    DWORD dwSize = (DWORD)size;
    
    // Use KEY_WOW64_64KEY to force 64-bit registry view
    if (RegOpenKeyExA(hKey, subKey, 0, KEY_READ | KEY_WOW64_64KEY, &hOpenKey) == ERROR_SUCCESS) {
        if (RegQueryValueExA(hOpenKey, valueName, NULL, &dwType, (LPBYTE)output, &dwSize) != ERROR_SUCCESS) {
            output[0] = '\0';
        }
        RegCloseKey(hOpenKey);
    } else {
        output[0] = '\0';
    }
}

void GetOSName(char* osName, size_t size) {
    char productName[256] = {0};
    char buildNumber[256] = {0};
    DWORD buildNum = 0;
    
    // Get ProductName
    GetRegistryValue(HKEY_LOCAL_MACHINE, 
                     "SOFTWARE\\Microsoft\\Windows NT\\CurrentVersion",
                     "ProductName", productName, sizeof(productName));
    
    // Get Build Number
    GetRegistryValue(HKEY_LOCAL_MACHINE,
                     "SOFTWARE\\Microsoft\\Windows NT\\CurrentVersion",
                     "CurrentBuild", buildNumber, sizeof(buildNumber));
    
    buildNum = atoi(buildNumber);
    
    // If build >= 22000, it's Windows 11 (even if ProductName says 10)
    if (buildNum >= 22000 && strstr(productName, "Windows 10") != NULL) {
        // Replace "10" with "11"
        char* pos = strstr(productName, "Windows 10");
        if (pos != NULL) {
            pos[8] = '1';  // Change "10" to "11"
            pos[9] = '1';
        }
    }
    
    strncpy(osName, productName, size - 1);
    osName[size - 1] = '\0';
}

void GetProcessorInfo(char* processorName, size_t size) {
    // Read real processor name from registry
    GetRegistryValue(HKEY_LOCAL_MACHINE,
                     "HARDWARE\\DESCRIPTION\\System\\CentralProcessor\\0",
                     "ProcessorNameString", processorName, size);
    
    // Trim leading spaces
    char* start = processorName;
    while (*start == ' ') start++;
    
    if (start != processorName) {
        memmove(processorName, start, strlen(start) + 1);
    }
    
    // Remove trailing spaces
    char* end = processorName + strlen(processorName) - 1;
    while (end > processorName && *end == ' ') {
        *end = '\0';
        end--;
    }
}

void GetSystemUptime(char* bootTime, size_t size) {
    FILETIME ft;
    SYSTEMTIME st, lt;
    ULARGE_INTEGER ull;
    
    GetSystemTimeAsFileTime(&ft);
    ull.LowPart = ft.dwLowDateTime;
    ull.HighPart = ft.dwHighDateTime;
    
    // Subtract random 3-7 hours
    srand((unsigned int)time(NULL));
    int hoursAgo = 3 + (rand() % 5);
    ull.QuadPart -= (ULONGLONG)hoursAgo * 10000000ULL * 3600;
    
    ft.dwLowDateTime = ull.LowPart;
    ft.dwHighDateTime = ull.HighPart;
    
    FileTimeToSystemTime(&ft, &st);
    SystemTimeToTzSpecificLocalTime(NULL, &st, &lt);
    
    sprintf(bootTime, "%d/%d/%d, %d:%02d:%02d %s",
            lt.wMonth, lt.wDay, lt.wYear,
            (lt.wHour % 12 == 0) ? 12 : lt.wHour % 12,
            lt.wMinute, lt.wSecond,
            (lt.wHour >= 12) ? "PM" : "AM");
}

void SpoofAdapterName(const char* realName, char* spoofedName, size_t size) {
    // If it contains VMware or virtual keywords, replace with Intel
    if (strstr(realName, "VMware") || strstr(realName, "vmxnet") || 
        strstr(realName, "Virtual") || strstr(realName, "virtual")) {
        strncpy(spoofedName, "Intel(R) Ethernet Connection I219-LM", size - 1);
        spoofedName[size - 1] = '\0';
    } else {
        strncpy(spoofedName, realName, size - 1);
        spoofedName[size - 1] = '\0';
    }
}

void PrintNetworkInfo() {
    PIP_ADAPTER_ADDRESSES pAddresses = NULL;
    PIP_ADAPTER_ADDRESSES pCurrAddresses = NULL;
    PIP_ADAPTER_UNICAST_ADDRESS pUnicast = NULL;
    ULONG outBufLen = 15000;
    DWORD dwRetVal = 0;
    int nicCount = 0;
    
    pAddresses = (IP_ADAPTER_ADDRESSES*)malloc(outBufLen);
    
    if (pAddresses == NULL) {
        printf("Network Card(s):           Unable to retrieve network information\n");
        return;
    }
    
    dwRetVal = GetAdaptersAddresses(AF_UNSPEC, 
                                    GAA_FLAG_INCLUDE_PREFIX | GAA_FLAG_INCLUDE_GATEWAYS,
                                    NULL, pAddresses, &outBufLen);
    
    if (dwRetVal == ERROR_BUFFER_OVERFLOW) {
        free(pAddresses);
        pAddresses = (IP_ADAPTER_ADDRESSES*)malloc(outBufLen);
        if (pAddresses == NULL) {
            printf("Network Card(s):           Unable to retrieve network information\n");
            return;
        }
        dwRetVal = GetAdaptersAddresses(AF_UNSPEC,
                                        GAA_FLAG_INCLUDE_PREFIX | GAA_FLAG_INCLUDE_GATEWAYS,
                                        NULL, pAddresses, &outBufLen);
    }
    
    if (dwRetVal == NO_ERROR) {
        pCurrAddresses = pAddresses;
        
        // Count active adapters
        while (pCurrAddresses) {
            if (pCurrAddresses->OperStatus == IfOperStatusUp && 
                pCurrAddresses->FirstUnicastAddress != NULL) {
                nicCount++;
            }
            pCurrAddresses = pCurrAddresses->Next;
        }
        
        printf("Network Card(s):           %d NIC(s) Installed.\n", nicCount);
        
        pCurrAddresses = pAddresses;
        int adapterNum = 1;
        
        while (pCurrAddresses) {
            if (pCurrAddresses->OperStatus == IfOperStatusUp && 
                pCurrAddresses->FirstUnicastAddress != NULL) {
                
                char realNameAnsi[256];
                char spoofedName[256];
                
                // Convert wide string (Unicode) to ANSI string
                WideCharToMultiByte(CP_ACP, 0, pCurrAddresses->Description, -1, 
                                    realNameAnsi, sizeof(realNameAnsi), NULL, NULL);
                
                SpoofAdapterName(realNameAnsi, spoofedName, sizeof(spoofedName));
                
                printf("                           [%02d]: %s\n", adapterNum, spoofedName);
                printf("                                 Connection Name: %S\n", pCurrAddresses->FriendlyName);
                printf("                                 DHCP Enabled:    %s\n", 
                       (pCurrAddresses->Flags & IP_ADAPTER_DHCP_ENABLED) ? "Yes" : "No");
                
                // Get DHCP server if available
                if (pCurrAddresses->Flags & IP_ADAPTER_DHCP_ENABLED && 
                    pCurrAddresses->Dhcpv4Server.iSockaddrLength > 0) {
                    
                    char dhcpServer[INET6_ADDRSTRLEN];
                    
                    if (pCurrAddresses->Dhcpv4Server.lpSockaddr->sa_family == AF_INET) {
                        struct sockaddr_in* pAddr = (struct sockaddr_in*)pCurrAddresses->Dhcpv4Server.lpSockaddr;
                        inet_ntop(AF_INET, &(pAddr->sin_addr), dhcpServer, sizeof(dhcpServer));
                        printf("                                 DHCP Server:     %s\n", dhcpServer);
                    }
                }
                
                printf("                                 IP address(es)\n");
                
                pUnicast = pCurrAddresses->FirstUnicastAddress;
                int ipNum = 1;
                
                while (pUnicast != NULL) {
                    char ipString[INET6_ADDRSTRLEN];
                    
                    if (pUnicast->Address.lpSockaddr->sa_family == AF_INET) {
                        struct sockaddr_in* pAddr = (struct sockaddr_in*)pUnicast->Address.lpSockaddr;
                        inet_ntop(AF_INET, &(pAddr->sin_addr), ipString, sizeof(ipString));
                        printf("                                 [%02d]: %s\n", ipNum, ipString);
                        ipNum++;
                    } else if (pUnicast->Address.lpSockaddr->sa_family == AF_INET6) {
                        struct sockaddr_in6* pAddr6 = (struct sockaddr_in6*)pUnicast->Address.lpSockaddr;
                        inet_ntop(AF_INET6, &(pAddr6->sin6_addr), ipString, sizeof(ipString));
                        printf("                                 [%02d]: %s\n", ipNum, ipString);
                        ipNum++;
                    }
                    
                    pUnicast = pUnicast->Next;
                }
                
                adapterNum++;
            }
            pCurrAddresses = pCurrAddresses->Next;
        }
    } else {
        printf("Network Card(s):           Unable to retrieve network information\n");
    }
    
    if (pAddresses) {
        free(pAddresses);
    }
}

void PrintSystemInfo() {
    char hostname[256] = {0};
    char osName[256] = {0};
    char osVersion[256] = {0};
    char osBuild[256] = {0};
    char owner[256] = {0};
    char organization[256] = {0};
    char productId[256] = {0};
    char bootTime[128] = {0};
    char processorName[256] = {0};
    
    // Hardware/BIOS info from registry
    char systemManufacturer[256] = {0};
    char systemProductName[256] = {0};
    char biosVendor[256] = {0};
    char biosVersion[256] = {0};
    char biosReleaseDate[256] = {0};
    char baseBoardManufacturer[256] = {0};
    char baseBoardProduct[256] = {0};
    
    DWORD size = sizeof(hostname);
    GetComputerNameA(hostname, &size);
    
    // Get OS info using the new function that handles Win10/11 detection
    GetOSName(osName, sizeof(osName));
    
    GetRegistryValue(HKEY_LOCAL_MACHINE,
                     "SOFTWARE\\Microsoft\\Windows NT\\CurrentVersion",
                     "CurrentVersion", osVersion, sizeof(osVersion));
    
    GetRegistryValue(HKEY_LOCAL_MACHINE,
                     "SOFTWARE\\Microsoft\\Windows NT\\CurrentVersion",
                     "CurrentBuild", osBuild, sizeof(osBuild));
    
    GetRegistryValue(HKEY_LOCAL_MACHINE,
                     "SOFTWARE\\Microsoft\\Windows NT\\CurrentVersion",
                     "RegisteredOwner", owner, sizeof(owner));
    
    GetRegistryValue(HKEY_LOCAL_MACHINE,
                     "SOFTWARE\\Microsoft\\Windows NT\\CurrentVersion",
                     "RegisteredOrganization", organization, sizeof(organization));
    
    GetRegistryValue(HKEY_LOCAL_MACHINE,
                     "SOFTWARE\\Microsoft\\Windows NT\\CurrentVersion",
                     "ProductId", productId, sizeof(productId));
    
    // Get hardware info from BIOS registry keys
    GetRegistryValue(HKEY_LOCAL_MACHINE,
                     "HARDWARE\\DESCRIPTION\\System\\BIOS",
                     "SystemManufacturer", systemManufacturer, sizeof(systemManufacturer));
    
    GetRegistryValue(HKEY_LOCAL_MACHINE,
                     "HARDWARE\\DESCRIPTION\\System\\BIOS",
                     "SystemProductName", systemProductName, sizeof(systemProductName));
    
    GetRegistryValue(HKEY_LOCAL_MACHINE,
                     "HARDWARE\\DESCRIPTION\\System\\BIOS",
                     "BIOSVendor", biosVendor, sizeof(biosVendor));
    
    GetRegistryValue(HKEY_LOCAL_MACHINE,
                     "HARDWARE\\DESCRIPTION\\System\\BIOS",
                     "BIOSVersion", biosVersion, sizeof(biosVersion));
    
    GetRegistryValue(HKEY_LOCAL_MACHINE,
                     "HARDWARE\\DESCRIPTION\\System\\BIOS",
                     "BIOSReleaseDate", biosReleaseDate, sizeof(biosReleaseDate));
    
    GetRegistryValue(HKEY_LOCAL_MACHINE,
                     "HARDWARE\\DESCRIPTION\\System\\BIOS",
                     "BaseBoardManufacturer", baseBoardManufacturer, sizeof(baseBoardManufacturer));
    
    GetRegistryValue(HKEY_LOCAL_MACHINE,
                     "HARDWARE\\DESCRIPTION\\System\\BIOS",
                     "BaseBoardProduct", baseBoardProduct, sizeof(baseBoardProduct));
    
    // Get processor info
    GetProcessorInfo(processorName, sizeof(processorName));
    
    // Calculate fake boot time
    GetSystemUptime(bootTime, sizeof(bootTime));
    
    // Print system info
    printf("\n");
    printf("Host Name:                 %s\n", hostname);
    printf("OS Name:                   %s\n", strlen(osName) ? osName : "Microsoft Windows 11 Pro");
    printf("OS Version:                10.0.%s N/A Build %s\n", osBuild, osBuild);
    printf("OS Manufacturer:           Microsoft Corporation\n");
    printf("OS Configuration:          Standalone Workstation\n");
    printf("OS Build Type:             Multiprocessor Free\n");
    printf("Registered Owner:          %s\n", strlen(owner) ? owner : "N/A");
    printf("Registered Organization:   %s\n", strlen(organization) ? organization : "N/A");
    printf("Product ID:                %s\n", strlen(productId) ? productId : "00355-62332-78969-AAOEM");
    printf("Original Install Date:     9/3/2024, 1:08:05 PM\n");
    printf("System Boot Time:          %s\n", bootTime);
    
    // Use registry values if available, otherwise use defaults
    printf("System Manufacturer:       %s\n", 
           strlen(systemManufacturer) ? systemManufacturer : "Dell Inc.");
    printf("System Model:              %s\n", 
           strlen(systemProductName) ? systemProductName : "Dell Pro 13 Plus PB13255");
    printf("System Type:               x64-based PC\n");
    
    // Print processor info
    printf("Processor(s):              1 Processor(s) Installed.\n");
    if (strlen(processorName) > 0) {
        printf("                           [01]: %s\n", processorName);
    } else {
        printf("                           [01]: Intel(R) Xeon(R) Gold 6130 CPU @ 2.10GHz\n");
    }
    
    // Build BIOS string from registry values or use default
    if (strlen(biosVendor) && strlen(biosVersion) && strlen(biosReleaseDate)) {
        printf("BIOS Version:              %s %s, %s\n", biosVendor, biosVersion, biosReleaseDate);
    } else {
        printf("BIOS Version:              Dell Inc. 1.8.1, 10/27/2025\n");
    }
    
    // Real system paths
    printf("Windows Directory:         C:\\Windows\n");
    printf("System Directory:          C:\\Windows\\system32\n");
    printf("Boot Device:               \\Device\\HarddiskVolume1\n");
    printf("System Locale:             en-us;English (United States)\n");
    printf("Input Locale:              en-us;English (United States)\n");
    printf("Time Zone:                 (UTC-08:00) Pacific Time (US & Canada)\n");
    
    // Memory info
    MEMORYSTATUSEX memInfo;
    memInfo.dwLength = sizeof(MEMORYSTATUSEX);
    GlobalMemoryStatusEx(&memInfo);
    
    DWORDLONG totalMB = memInfo.ullTotalPhys / (1024 * 1024);
    DWORDLONG availMB = memInfo.ullAvailPhys / (1024 * 1024);
    DWORDLONG totalVirtMB = memInfo.ullTotalVirtual / (1024 * 1024);
    DWORDLONG availVirtMB = memInfo.ullAvailVirtual / (1024 * 1024);
    
    printf("Total Physical Memory:     %llu MB\n", totalMB);
    printf("Available Physical Memory: %llu MB\n", availMB);
    printf("Virtual Memory: Max Size:  %llu MB\n", totalVirtMB);
    printf("Virtual Memory: Available: %llu MB\n", availVirtMB);
    printf("Virtual Memory: In Use:    %llu MB\n", totalVirtMB - availVirtMB);
    printf("Page File Location(s):     C:\\pagefile.sys\n");
    printf("Domain:                    WORKGROUP\n");
    printf("Logon Server:              \\\\%s\n", hostname);
    
    // Hotfixes
    printf("Hotfix(s):                 3 Hotfix(s) Installed.\n");
    printf("                           [01]: KB5034441\n");
    printf("                           [02]: KB5034467\n");
    printf("                           [03]: KB5034848\n");
    
    // Real network information
    PrintNetworkInfo();
    
    printf("Hyper-V Requirements:      A hypervisor has been detected. Features required for Hyper-V will not be displayed.\n");
}

int main(int argc, char* argv[]) {
    // Handle /? help parameter
    if (argc > 1 && (strcmp(argv[1], "/?") == 0 || strcmp(argv[1], "-?") == 0)) {
        printf("\nSYSTEMINFO [/S system [/U username [/P [password]]]] [/FO format] [/NH]\n\n");
        printf("Description:\n");
        printf("    This command line tool enables an administrator to query for basic\n");
        printf("    system configuration information.\n\n");
        printf("Parameter List:\n");
        printf("    /S      system           Specifies the remote system to connect to.\n");
        printf("    /U      [domain\\]user    Specifies the user context under which\n");
        printf("                             the command should execute.\n");
        printf("    /P      [password]       Specifies the password for the given\n");
        printf("                             user context. Prompts for input if omitted.\n");
        printf("    /FO     format           Specifies the format in which the output\n");
        printf("                             is to be displayed.\n");
        printf("                             Valid values: \"TABLE\", \"LIST\", \"CSV\".\n");
        printf("    /NH                      Specifies that the \"Column Header\" should\n");
        printf("                             not be displayed in the output.\n");
        printf("                             Valid only for \"TABLE\" and \"CSV\" formats.\n");
        printf("    /?                       Displays this help message.\n\n");
        printf("Examples:\n");
        printf("    SYSTEMINFO\n");
        printf("    SYSTEMINFO /?\n");
        printf("    SYSTEMINFO /S system\n");
        printf("    SYSTEMINFO /S system /U user\n");
        printf("    SYSTEMINFO /S system /U domain\\user /P password /FO TABLE\n");
        printf("    SYSTEMINFO /S system /FO LIST\n");
        printf("    SYSTEMINFO /S system /FO CSV /NH\n");
        return 0;
    }
    
    PrintSystemInfo();
    return 0;
}
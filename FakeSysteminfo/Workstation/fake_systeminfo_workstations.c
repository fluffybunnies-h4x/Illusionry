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
    
    GetRegistryValue(HKEY_LOCAL_MACHINE,
                     "SOFTWARE\\Microsoft\\Windows NT\\CurrentVersion",
                     "ProductName", productName, sizeof(productName));
    
    GetRegistryValue(HKEY_LOCAL_MACHINE,
                     "SOFTWARE\\Microsoft\\Windows NT\\CurrentVersion",
                     "CurrentBuild", buildNumber, sizeof(buildNumber));
    
    buildNum = atoi(buildNumber);
    
    // Build >= 22000 is Windows 11; fix ProductName if it still says Windows 10
    if (buildNum >= 22000 && strstr(productName, "Windows 10") != NULL) {
        char* pos = strstr(productName, "Windows 10");
        if (pos != NULL) {
            pos[8] = '1';
            pos[9] = '1';
        }
    }
    
    strncpy(osName, productName, size - 1);
    osName[size - 1] = '\0';
}

void GetProcessorInfo(char* processorName, size_t size) {
    GetRegistryValue(HKEY_LOCAL_MACHINE,
                     "HARDWARE\\DESCRIPTION\\System\\CentralProcessor\\0",
                     "ProcessorNameString", processorName, size);
    
    char* start = processorName;
    while (*start == ' ') start++;
    if (start != processorName) {
        memmove(processorName, start, strlen(start) + 1);
    }
    
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
    
    // Subtract random 3-7 hours to simulate a recently booted consumer machine
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
    // Map VM/virtual NICs to plausible consumer hardware
    if (strstr(realName, "VMware") || strstr(realName, "vmxnet") ||
        strstr(realName, "VMXNET") || strstr(realName, "VMnet")) {
        // Consumer desktops/laptops commonly use Intel I219 or Realtek PCIe GbE
        strncpy(spoofedName, "Realtek PCIe GbE Family Controller", size - 1);
        spoofedName[size - 1] = '\0';
    } else if (strstr(realName, "Virtual") || strstr(realName, "virtual") ||
               strstr(realName, "VirtualBox") || strstr(realName, "Hyper-V") ||
               strstr(realName, "TAP") || strstr(realName, "tap")) {
        // Second virtual adapter → spoof as Intel Wi-Fi (common on Win11 laptops)
        strncpy(spoofedName, "Intel(R) Wi-Fi 6 AX201 160MHz", size - 1);
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
                
                WideCharToMultiByte(CP_ACP, 0, pCurrAddresses->Description, -1,
                                    realNameAnsi, sizeof(realNameAnsi), NULL, NULL);
                
                SpoofAdapterName(realNameAnsi, spoofedName, sizeof(spoofedName));
                
                printf("                           [%02d]: %s\n", adapterNum, spoofedName);
                printf("                                 Connection Name: %S\n", pCurrAddresses->FriendlyName);
                printf("                                 DHCP Enabled:    %s\n",
                       (pCurrAddresses->Flags & IP_ADAPTER_DHCP_ENABLED) ? "Yes" : "No");
                
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
    char hostname[256]             = {0};
    char osName[256]               = {0};
    char osVersion[256]            = {0};
    char osBuild[256]              = {0};
    char owner[256]                = {0};
    char organization[256]         = {0};
    char productId[256]            = {0};
    char bootTime[128]             = {0};
    char processorName[256]        = {0};
    char systemManufacturer[256]   = {0};
    char systemProductName[256]    = {0};
    char biosVendor[256]           = {0};
    char biosVersion[256]          = {0};
    char biosReleaseDate[256]      = {0};
    char baseBoardManufacturer[256]= {0};
    char baseBoardProduct[256]     = {0};
    
    DWORD size = sizeof(hostname);
    GetComputerNameA(hostname, &size);
    
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
    
    GetProcessorInfo(processorName, sizeof(processorName));
    GetSystemUptime(bootTime, sizeof(bootTime));
    
    printf("\n");
    printf("Host Name:                 %s\n", hostname);
    // Win11 Home is very common on consumer hardware; fall back to Home if registry is empty
    printf("OS Name:                   %s\n", strlen(osName) ? osName : "Microsoft Windows 11 Home");
    printf("OS Version:                10.0.%s N/A Build %s\n", osBuild, osBuild);
    printf("OS Manufacturer:           Microsoft Corporation\n");
    printf("OS Configuration:          Standalone Workstation\n");
    printf("OS Build Type:             Multiprocessor Free\n");
    printf("Registered Owner:          %s\n", strlen(owner) ? owner : "N/A");
    printf("Registered Organization:   %s\n", strlen(organization) ? organization : "N/A");
    printf("Product ID:                %s\n", strlen(productId) ? productId : "00342-35665-12345-AAOEM");
    // Typical OEM Win11 install date
    printf("Original Install Date:     3/14/2024, 10:22:17 AM\n");
    printf("System Boot Time:          %s\n", bootTime);
    
    // Consumer defaults: Dell XPS 15 (very common Win11 machine)
    printf("System Manufacturer:       %s\n",
           strlen(systemManufacturer) ? systemManufacturer : "Dell Inc.");
    printf("System Model:              %s\n",
           strlen(systemProductName) ? systemProductName : "XPS 15 9530");
    printf("System Type:               x64-based PC\n");
    
    // Consumer CPU fallback: Intel Core i7-13700H (common in 2023/2024 laptops/desktops)
    printf("Processor(s):              1 Processor(s) Installed.\n");
    if (strlen(processorName) > 0) {
        printf("                           [01]: %s\n", processorName);
    } else {
        printf("                           [01]: Intel(R) Core(TM) i7-13700H   2.40GHz\n");
    }
    
    // BIOS fallback: Dell UEFI firmware typical of XPS 2023/2024
    if (strlen(biosVendor) && strlen(biosVersion) && strlen(biosReleaseDate)) {
        printf("BIOS Version:              %s %s, %s\n", biosVendor, biosVersion, biosReleaseDate);
    } else {
        printf("BIOS Version:              Dell Inc. 1.14.1, 08/15/2024\n");
    }
    
    printf("Windows Directory:         C:\\Windows\n");
    printf("System Directory:          C:\\Windows\\system32\n");
    printf("Boot Device:               \\Device\\HarddiskVolume1\n");
    printf("System Locale:             en-us;English (United States)\n");
    printf("Input Locale:              en-us;English (United States)\n");
    // Central time is more statistically common for US consumer machines
    printf("Time Zone:                 (UTC-06:00) Central Time (US & Canada)\n");
    
    MEMORYSTATUSEX memInfo;
    memInfo.dwLength = sizeof(MEMORYSTATUSEX);
    GlobalMemoryStatusEx(&memInfo);
    
    DWORDLONG totalMB    = memInfo.ullTotalPhys    / (1024 * 1024);
    DWORDLONG availMB    = memInfo.ullAvailPhys    / (1024 * 1024);
    DWORDLONG totalVirtMB= memInfo.ullTotalVirtual / (1024 * 1024);
    DWORDLONG availVirtMB= memInfo.ullAvailVirtual / (1024 * 1024);
    
    printf("Total Physical Memory:     %llu MB\n", totalMB);
    printf("Available Physical Memory: %llu MB\n", availMB);
    printf("Virtual Memory: Max Size:  %llu MB\n", totalVirtMB);
    printf("Virtual Memory: Available: %llu MB\n", availVirtMB);
    printf("Virtual Memory: In Use:    %llu MB\n", totalVirtMB - availVirtMB);
    printf("Page File Location(s):     C:\\pagefile.sys\n");
    printf("Domain:                    WORKGROUP\n");
    printf("Logon Server:              \\\\%s\n", hostname);
    
    // Win11 23H2 / 24H2 era hotfixes (KB5044284 = Win11 23H2 Oct 2024 CU,
    // KB5046617 = Nov 2024 CU, KB5048685 = Dec 2024 CU)
    printf("Hotfix(s):                 3 Hotfix(s) Installed.\n");
    printf("                           [01]: KB5044284\n");
    printf("                           [02]: KB5046617\n");
    printf("                           [03]: KB5048685\n");
    
    PrintNetworkInfo();
    
    // Win11 on modern hardware with TPM 2.0 + Secure Boot: Hyper-V CAN be enabled.
    // Real Win11 machines without Hyper-V enabled show this line instead of the
    // "hypervisor has been detected" line used by the server build.
    printf("Hyper-V Requirements:      VM Monitor Mode Extensions: Yes\n");
    printf("                           Virtualization Enabled In Firmware: Yes\n");
    printf("                           Second Level Address Translation: Yes\n");
    printf("                           Data Execution Prevention Available: Yes\n");
}

int main(int argc, char* argv[]) {
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
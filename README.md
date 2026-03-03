<img width="1024" height="576" alt="illusionry" src="https://github.com/user-attachments/assets/20360592-7ad1-4c05-b914-0b26e28960db" />

# Illusionry — VM Evasion Toolkit for Malware Analysis

A layered toolkit for making a VMware guest appear to be physical hardware, defeating common malware anti-analysis / sandbox-evasion checks so that samples run their full payload for analysis rather than self-destructing.

> **Intended use:** Isolated malware analysis VMs, honeypots, and threat intelligence research environments. Not for production systems.

---

## Architecture Overview

Malware typically uses several independent channels to detect a VM. Illusionry defeats them at each layer:

| Channel | Malware Technique | Illusionry Defense |
|---|---|---|
| Registry BIOS keys | Read `HKLM\HARDWARE\DESCRIPTION\System\BIOS` | `windows_update.ps1` patches all keys |
| `systeminfo.exe` | Parse CLI output for "VMware" strings | `fake_systeminfo.exe` reads patched registry and outputs clean data |
| `wmic.exe` | `wmic csproduct get vendor` / `wmic os get caption` | `fake_wmic.exe` intercepts all common queries |
| WMI / CIM (PowerShell) | `Get-CimInstance Win32_ComputerSystem` | PS profile hooks `Get-WmiObject` and `Get-CimInstance` |
| `-NoProfile` bypass | `powershell -NoProfile -Command "..."` | PowerShell wrapper strips `-NoProfile` flag |
| Sysmon process detection | Check for `Sysmon64.exe` or `Sysmon` service | Renamed binary + service installed as `Diag64` |
| VMware Tools services | Check for `VMTools`, `VGAuthService` processes | `windows_update.ps1` disables all VMware services |

---

## Building from Source

Three components require compilation before deployment: the fake `systeminfo.exe` binaries (C), the fake `wmic.exe` binary (C), and the PowerShell wrapper (C#). All require the Microsoft Visual C++ toolchain.

### Visual Studio Requirements

**Required install:** [Visual Studio 2022](https://visualstudio.microsoft.com/) (Community edition is free) with the **"Desktop development with C++"** workload selected. This provides:

| Tool | Purpose |
|---|---|
| `cl.exe` | MSVC C/C++ compiler — compiles all three `.c` source files |
| `link.exe` | Linker (invoked automatically by `cl.exe /link`) |
| `csc.exe` | C# compiler — compiles `PowerShellWrapper.cs` |
| Windows SDK headers | `windows.h`, `winsock2.h`, `iphlpapi.h`, etc. |
| Windows SDK libs | `advapi32.lib`, `iphlpapi.lib`, `ws2_32.lib` |

Alternatively, install **Build Tools for Visual Studio 2022** (no IDE, compiler toolchain only) and select the same "Desktop development with C++" workload — this is the lighter-weight option for a dedicated analysis VM.

**Critical:** All compile commands must be run from an **x64 Native Tools Command Prompt for VS 2022** (or the year-equivalent). This prompt is in the Start Menu under `Visual Studio 2022 →` and pre-configures `PATH`, `INCLUDE`, `LIB`, and `LIBPATH` so that `cl.exe`, the Windows SDK headers, and the import libraries are all found automatically. Running from a regular `cmd.exe` will produce `'cl' is not recognized` or missing header errors.

To open it:
```
Start → Visual Studio 2022 → x64 Native Tools Command Prompt for VS 2022
```

Or search the Start Menu for `x64 Native Tools`.

---

### Compiling `fake_wmic.c`

```batch
cd FakeWMIC
cl.exe /O2 /Fe:wmic.exe fake_wmic.c /link /SUBSYSTEM:CONSOLE advapi32.lib
```

| Flag | Meaning |
|---|---|
| `/O2` | Optimize for speed |
| `/Fe:wmic.exe` | Output executable named `wmic.exe` |
| `advapi32.lib` | Required for registry API calls (`RegOpenKeyExA`, `RegQueryValueExA`) |

---

### Compiling `fake_systeminfo` — Workstation

```batch
cd FakeSysteminfo\Workstation
cl.exe /O2 /Fe:systeminfo.exe fake_systeminfo_workstations.c /link /SUBSYSTEM:CONSOLE advapi32.lib iphlpapi.lib ws2_32.lib
```

### Compiling `fake_systeminfo` — Server

```batch
cd FakeSysteminfo\Server
cl.exe /O2 /Fe:systeminfo.exe fake_systeminfo_server.c /link /SUBSYSTEM:CONSOLE advapi32.lib iphlpapi.lib ws2_32.lib
```

| Flag / Lib | Meaning |
|---|---|
| `/O2` | Optimize for speed |
| `/Fe:systeminfo.exe` | Output executable named `systeminfo.exe` |
| `advapi32.lib` | Registry API |
| `iphlpapi.lib` | IP Helper API — required for network adapter enumeration (`GetAdaptersInfo`) |
| `ws2_32.lib` | Winsock2 — required for `winsock2.h` / `ws2tcpip.h` includes |

---

### Compiling `PowerShellWrapper.cs`

The `BUILD-WRAPPER.bat` script handles this automatically when run from the correct prompt:

```batch
cd FakePowershell
BUILD-WRAPPER.bat
```

Or manually:

```batch
csc /out:powershell.exe /platform:x64 /optimize+ PowerShellWrapper.cs
```

| Flag | Meaning |
|---|---|
| `/out:powershell.exe` | Output named `powershell.exe` |
| `/platform:x64` | Compile as 64-bit — must match the system PowerShell architecture |
| `/optimize+` | Enable optimizations |

`csc.exe` is available in both the Developer Command Prompt and the x64 Native Tools prompt when Visual Studio is installed.

---

## Deployment Order

### Stage 1 — Registry Patching (`windows_update.ps1`)

**Run first.** Patches every registry path that `systeminfo`, WMI, and CIM queries read from. Also sets up a scheduled task for post-reboot persistence.

**Interactive wizard prompts:**
- System type: Server or Workstation
- OS version (e.g. Windows 10 Pro, Windows Server 2019 Standard)
- Processor (realistic Intel/AMD CPUs appropriate for the system type)
- Hostname, Registered Owner, Organization
- Manufacturer, Model, Board product number
- BIOS version and release date (auto-generates realistic values per OEM)
- Serial number (format-correct for the selected OEM — Dell 7-char, HPE `CZ`-prefix, etc.)
- Machine GUID (optionally regenerates)
- MAC address (optional; sets OUI matching the chosen manufacturer)
- VMware Tools disable (stops and disables `VMTools`, `VGAuthService`, `vm3dservice`)
- Scheduled task creation for persistence

**Registry paths patched:**
```
HKLM\HARDWARE\DESCRIPTION\System\BIOS
  BaseBoardManufacturer, BaseBoardProduct, BIOSVendor, BIOSVersion,
  BIOSReleaseDate, SystemManufacturer, SystemProductName, SystemSKU,
  SystemFamily, EnclosureType, ECFirmware*

HKLM\HARDWARE\DESCRIPTION\System\CentralProcessor\[0..N]
  ProcessorNameString, ~MHz, VendorIdentifier

HKLM\SYSTEM\CurrentControlSet\Control\SystemInformation
  SystemManufacturer, SystemProductName, BIOSVendor, BIOSVersion, BIOSReleaseDate

HKLM\SOFTWARE\Microsoft\Windows NT\CurrentVersion
  ProductName, RegisteredOwner, RegisteredOrganization

HKLM\SOFTWARE\Microsoft\Cryptography
  MachineGuid
```

**Persistence mechanism:** Optionally writes a boot-triggered scheduled task (e.g. `WindowsUpdateCheck`) running as SYSTEM that re-applies all registry patches 1 minute after startup. This is necessary because some hypervisors (notably ESXi 8.0.3) reset SMBIOS-related keys on reboot.

```powershell
# Run as Administrator
.\windows_update.ps1
```

---

### Stage 2 — Fake Binaries (`deploy_fakes.bat`)

**Run second.** Replaces the real `systeminfo.exe` and `wmic.exe` in System32 with compiled fake versions that read from the patched registry and output clean, non-VM data.

The script uses `takeown` + `icacls` to acquire write permission on protected system files, then performs the replacement atomically. For `wmic.exe` the original is renamed to `wmic.exe.bak` as a safety measure.

```
Source files:
  FakeSysteminfo\Workstation\systeminfo.exe  →  C:\Windows\System32\systeminfo.exe
  FakeSysteminfo\Server\systeminfo.exe       →  C:\Windows\System32\systeminfo.exe
  FakeWMIC\wmic.exe                          →  C:\Windows\System32\wbem\wmic.exe
```

**Fake `systeminfo.exe`** (C source in `FakeSysteminfo\*/fake_systeminfo*.c`):
- Reads all relevant values from the patched registry paths
- Produces output in the exact format of the real `systeminfo.exe`
- Handles Windows 10/11 build number disambiguation (build ≥ 22000 = Windows 11)
- Workstation and Server variants output hardware appropriate for each role

**Fake `wmic.exe`** (C source in `FakeWMIC\fake_wmic.c`):
- Parses the command-line arguments to match known malware query patterns
- Reads unique IDs (SerialNumber, SystemUUID, DiskSerial) from `HKLM\SOFTWARE\VMEvasion`
- Returns spoofed output for: `csproduct`, `os`, `computersystem`, `cpu`, `bios`, `diskdrive`, `nic`, `baseboard`

> See [Building from Source](#building-from-source) for compile commands and Visual Studio requirements.

**Deploy** (run as Administrator from the project root, after copying the correct `systeminfo.exe` variant here):

```batch
:: Copy the correct variant to the project root first
copy FakeSysteminfo\Workstation\systeminfo.exe .   :: workstation
:: copy FakeSysteminfo\Server\systeminfo.exe .     :: server

copy FakeWMIC\wmic.exe .

:: Then deploy both
deploy_fakes.bat
```

---

### Stage 3 — PowerShell WMI Hooks (Profile Scripts)

**Run third.** Deploy the appropriate profile script as the system-wide PowerShell profile. This hooks `Get-WmiObject` and `Get-CimInstance` at the PowerShell function layer so that every PowerShell session — including those spawned by malware — returns spoofed hardware data.

```
PowershellProfiles\profile-workstation.ps1  →  C:\Windows\System32\WindowsPowerShell\v1.0\profile.ps1
PowershellProfiles\profile-server.ps1       →  C:\Windows\System32\WindowsPowerShell\v1.0\profile.ps1
```

**How the hooks work:**

1. On session start, the profile reads the configured identity from `HKLM\HARDWARE\DESCRIPTION\System\BIOS` (values set by Stage 1).
2. It generates (or retrieves from `HKLM\SOFTWARE\QUANTUMHardware`) persistent unique hardware IDs: Dell-format service tag, serial number, system UUID (starts with `44454C4C` = "DELL" in hex), and disk serial. These stay stable across sessions so the same fingerprint is returned consistently.
3. The real `Get-WmiObject` cmdlet is stored, then shadowed by a custom function.
4. `Get-CimInstance` is also shadowed and routed through the same function.
5. Both `gwmi` and `gcim` aliases are updated.

**WMI classes intercepted:**

| Class | What is spoofed |
|---|---|
| `Win32_BIOS` | Manufacturer, version, release date, serial, SMBIOS fields |
| `Win32_ComputerSystemProduct` | Vendor, name, UUID, serial |
| `Win32_ComputerSystem` | Manufacturer, Model |
| `Win32_BaseBoard` | Manufacturer, product, serial |
| `Win32_DiskDrive` | Model, caption, serial, interface type (VMware → Samsung NVMe or Dell PERC) |
| `Win32_NetworkAdapter` | Name, description, manufacturer (VMware → Intel NIC) |
| `Win32_NetworkAdapterConfiguration` | Description, service name |
| `Win32_VideoController` | Name, description (VMware SVGA → Intel Iris Xe or MS Basic Display) |
| `Win32_IDEController` | Name, manufacturer |
| `Win32_SCSIController` | Name, manufacturer, description |

The server profile uses server-appropriate hardware (Dell PERC H730P RAID, Intel I219-LM NIC, C600 chipset). The workstation profile uses workstation hardware (Samsung NVMe, Intel Wi-Fi 6E AX211, Intel Iris Xe GPU).

This stage directly defeats the canonical malware check:
```powershell
powershell -Command "Get-CimInstance Win32_ComputerSystem | Select Manufacturer, Model"
```
...but *only* when the profile is loaded. The `-NoProfile` bypass is handled in Stage 4.

---

### Stage 4 — PowerShell Wrapper (`Deploy-PowerShellWrapper.ps1`)

**Run last.** This is the critical stage that defeats `-NoProfile` evasion.

**The problem:** Malware commonly invokes PowerShell with `-NoProfile` to explicitly skip the global profile and prevent any hook injection:
```powershell
powershell -NoProfile -Command "if((Get-CimInstance Win32_ComputerSystem).Manufacturer -match 'VMware'){ exit 0 }"
```

**The solution:** Replace `powershell.exe` with a thin C# wrapper that intercepts the launch, silently strips the `-NoProfile` flag from the argument list, then calls the real PowerShell (renamed to `powershell_quantum.exe`). Because `-NoProfile` is gone, the profile (and all its WMI hooks) loads normally.

**Component files:**

| File | Purpose |
|---|---|
| `FakePowershell\PowerShellWrapper.cs` | C# wrapper source |
| `FakePowershell\BUILD-WRAPPER.bat` | Compile with `csc.exe /platform:x64` |
| `FakePowershell\powershell.exe` | Compiled wrapper (pre-built) |
| `FakePowershell\Deploy-PowerShellWrapper.ps1` | Deployment script |
| `FakePowershell\Rollback-PowerShellWrapper.ps1` | Restore original `powershell.exe` |
| `FakePowershell\Test-PowerShellWrapper.ps1` | Verify the hook is active |

**Wrapper behavior (`PowerShellWrapper.cs`):**
- `STRIP_NOPROFILE = true` — removes `-NoProfile`, `-noprofile`, and `-nop` from args
- Passes all other arguments through unchanged to `powershell_quantum.exe`
- Preserves and returns the real exit code
- Optional file logging at `C:\ProgramData\Quantum Research\Logs\powershell-wrapper.log`

**Deployment steps:**
```batch
:: Step 1 — Build (from x64 Native Tools Command Prompt for VS 2022)
cd FakePowershell
BUILD-WRAPPER.bat

:: Step 2 — Deploy (PowerShell as Administrator)
.\Deploy-PowerShellWrapper.ps1
```

> See [Building from Source](#building-from-source) for full `csc.exe` details and Visual Studio requirements.

The deploy script backs up the original to `powershell_quantum.exe` and a timestamped copy in `C:\ProgramData\Quantum Research\Backups\` before overwriting.

**File layout after deployment:**
```
C:\Windows\System32\WindowsPowerShell\v1.0\
  powershell.exe           ← wrapper (intercepts -NoProfile)
  powershell_quantum.exe   ← original PowerShell
```

---

### Stage 5 — Stealthy Sysmon (`Diagnostics\`)

**Optional but recommended.** Some malware will enumerate running processes and self-destruct if it detects `Sysmon64.exe` or a service named `Sysmon`. The Diagnostics folder contains a renamed Sysmon binary and config that install the monitoring driver under a different process and service name.

**Files:**
```
Diagnostics\Diagnostics.exe   ← Sysmon64.exe, renamed
Diagnostics\Diagnostics.xml   ← Sysmon config (forked from SwiftOnSecurity / bobby-tablez FT-Sysmon-Config v74)
```

**Installation command:**
```batch
.\Diagnostics.exe -i Diagnostics.xml -accepteula -d Diag64
```

The `-d Diag64` flag sets the driver name. The resulting service and process will be named `Diag64` rather than `Sysmon64`, bypassing process-name-based detection.

---

## Full Deployment Checklist

```
[ ] 1. Run windows_update.ps1 as Administrator
        - Choose Server or Workstation
        - Select OS, CPU, hostname, OEM, model
        - Generate serial/GUID or accept auto-values
        - Enable VMware Tools disabling: Y
        - Enable scheduled task (persistence): Y
        - Reboot when prompted

[ ] 2. Select the correct systeminfo.exe variant:
        - Workstation: copy FakeSysteminfo\Workstation\systeminfo.exe to project root
        - Server:      copy FakeSysteminfo\Server\systeminfo.exe to project root
        Then run deploy_fakes.bat as Administrator

[ ] 3. Copy the matching profile:
        - Workstation: copy PowershellProfiles\profile-workstation.ps1
        - Server:      copy PowershellProfiles\profile-server.ps1
        Destination: C:\Windows\System32\WindowsPowerShell\v1.0\profile.ps1

[ ] 4. Build and deploy the PowerShell wrapper:
        a. Open x64 Native Tools Command Prompt for VS
        b. cd FakePowershell && BUILD-WRAPPER.bat
        c. powershell -ExecutionPolicy Bypass .\Deploy-PowerShellWrapper.ps1
        d. Run Test-PowerShellWrapper.ps1 to verify

[ ] 5. (Optional) Install renamed Sysmon:
        .\Diagnostics\Diagnostics.exe -i Diagnostics\Diagnostics.xml -accepteula -d Diag64
```

---

## Verification Commands

After full deployment, these commands should return clean (non-VMware) values:

```powershell
# Should show chosen OEM and model, not "VMware, Inc." / "VMware Virtual Platform"
powershell -NoProfile -Command "Get-CimInstance Win32_ComputerSystem | Select Manufacturer, Model"

# Should show patched BIOS vendor and version
powershell -NoProfile -Command "Get-WmiObject Win32_BIOS | Select Manufacturer, SMBIOSBIOSVersion"

# Should show patched OS and hardware strings
systeminfo | findstr /i "manufacturer model bios os"

# Should return non-VMware values for common wmic checks
wmic csproduct get vendor,name
wmic bios get manufacturer,smbiosbiosversion
wmic os get caption
```

---

## Rollback

```powershell
# Remove PowerShell wrapper (restores original powershell.exe)
cd FakePowershell
.\Rollback-PowerShellWrapper.ps1

# Remove PS profile hooks
Remove-Item C:\Windows\System32\WindowsPowerShell\v1.0\profile.ps1

# Restore original wmic.exe
rename C:\Windows\System32\wbem\wmic.exe.bak wmic.exe

# Remove scheduled task (use the name chosen during windows_update.ps1)
Unregister-ScheduledTask -TaskName "WindowsUpdateCheck" -Confirm:$false

# Remove persistent hardware ID store
Remove-Item -Path HKLM:\SOFTWARE\QUANTUMHardware -Recurse
```

---

## Known Limitations

- **ESXi 8.0.3 SMBIOS bug:** Some hypervisor builds reset SMBIOS keys on reboot despite registry patches. The scheduled task persistence in Stage 1 mitigates this. The fake `systeminfo.exe` also reads registry directly, so it will always return the correct output regardless.
- **WMI provider host (WmiPrvSE.exe):** Native COM-based WMI calls that go directly to the WMI provider host (not through PowerShell) will not be intercepted by the profile hooks. These are addressed by the registry patches in Stage 1.
- **64-bit vs 32-bit PowerShell:** The profile deploys to the 64-bit PowerShell path. 32-bit PowerShell (`%SystemRoot%\SysWOW64\WindowsPowerShell\v1.0\`) has a separate profile location. If 32-bit PS coverage is needed, copy the profile there as well.
- **PowerShell 7 (pwsh.exe):** Not covered by these hooks. Separate profile deployment would be required for `$PSHOME\profile.ps1` under the PowerShell 7 install path.



# PowerShell Wrapper Solution - Complete Guide

## Why This is the Best Solution

The C# wrapper gives you **complete control** over all PowerShell execution:

✅ **System-wide** - Affects ALL PowerShell calls, including from malware  
✅ **Transparent** - Malware never knows it's being intercepted  
✅ **Configurable** - Strip `-NoProfile` or pass it through  
✅ **Auto-loading** - WMI hook loads with every PowerShell instance  
✅ **Permanent** - Works until you roll back  
✅ **Clean** - Easy to deploy and remove  

---

## How It Works

```
Malware executes: Z4kzp5ECtD5kBJCt.bat
  ↓
Bat calls: powershell.exe -NoProfile -Command "Get-CimInstance..."
  ↓
Windows loads: C:\Windows\System32\...\powershell.exe (YOUR WRAPPER)
  ↓
Wrapper:
  1. Loads WMIHook.dll into current process
  2. Strips -NoProfile flag (configurable)
  3. Calls powershell_real.exe with modified args
  ↓
Real PowerShell starts with hook loaded and no -NoProfile
  ↓
CimD module loads (because -NoProfile was stripped)
  ↓
Get-CimInstance returns "Dell Inc."
  ↓
Malware proceeds to second stage! ✅
```

---

## Installation (5 Steps - 10 Minutes)

### Step 1: Compile the Wrapper (2 min)

Open **"Developer Command Prompt for VS 2022"**:

```batch
cd C:\Your\Working\Directory
BUILD-WRAPPER.bat
```

**Expected output:**
```
[+] C# compiler found
[+] Compiling PowerShellWrapper.cs...
[SUCCESS] powershell.exe wrapper created!
```

**Alternative manual compile:**
```batch
csc /out:powershell.exe /platform:x64 /optimize+ PowerShellWrapper.cs
```

### Step 2: Review Configuration (1 min)

Open `PowerShellWrapper.cs` and check these settings:

```csharp
const string HOOK_DLL_PATH = @"C:\ProgramData\Quantum Research\Hooks\WMIHook.dll";
const string REAL_POWERSHELL = @"C:\Windows\System32\WindowsPowerShell\v1.0\powershell_real.exe";
const bool STRIP_NOPROFILE = true;   // ← Set to false to keep -NoProfile
const bool LOG_ENABLED = false;      // ← Set to true for debugging
```

**Recommended settings:**
- `STRIP_NOPROFILE = true` - Remove -NoProfile flag (your CimD module will load)
- `LOG_ENABLED = false` - Disable logging (better performance)

Recompile if you changed anything.

### Step 3: Deploy (2 min)

**PowerShell as Administrator:**

```powershell
.\Deploy-PowerShellWrapper.ps1
```

Type `DEPLOY` when prompted.

This will:
1. Backup original `powershell.exe`
2. Rename it to `powershell_real.exe`
3. Install wrapper as `powershell.exe`

### Step 4: Test (1 min)

```powershell
.\Test-PowerShellWrapper.ps1
```

**Expected output:**
```
[Test 3] Testing -NoProfile flag (CRITICAL TEST)...
  Manufacturer: Dell Inc.
  Model: Latitude 7420
  [PASS] VM detection BLOCKED with -NoProfile!

Tests Passed: 5
[SUCCESS] All tests passed!
```

### Step 5: Run Your Malware

```batch
C:\path\to\Z4kzp5ECtD5kBJCt.bat
```

The malware should now execute its second stage! 🎯

---

## Configuration Options

### Option 1: Strip -NoProfile (Recommended)

```csharp
const bool STRIP_NOPROFILE = true;
```

**How it works:**
- Malware calls: `powershell.exe -NoProfile -Command "..."`
- Wrapper calls: `powershell.exe -Command "..."` (no -NoProfile)
- Your CimD module loads automatically
- VM detection returns "Dell Inc."

**Pros:** Uses your existing CimD module, no DLL needed  
**Cons:** Profile loading adds slight delay

### Option 2: Keep -NoProfile, Use DLL Hook

```csharp
const bool STRIP_NOPROFILE = false;
```

**How it works:**
- Malware calls: `powershell.exe -NoProfile -Command "..."`
- Wrapper calls: `powershell.exe -NoProfile -Command "..."` (unchanged)
- WMIHook.dll loads via wrapper
- VM detection returns "Dell Inc." via DLL hook

**Pros:** Faster, no profile loading  
**Cons:** Requires WMIHook.dll to be deployed

### Option 3: Both (Belt and Suspenders)

```csharp
const bool STRIP_NOPROFILE = true;  // Strip flag
// AND have WMIHook.dll deployed     // DLL loads anyway
```

**Best of both worlds:**
- CimD module loads (flag stripped)
- DLL hook also active (backup)
- Double protection against VM detection

---

## Testing Different Scenarios

### Test 1: Normal PowerShell
```powershell
powershell -Command "Get-CimInstance Win32_ComputerSystem | Select Manufacturer"
```
**Expected:** Dell Inc.

### Test 2: With -NoProfile (The Critical One)
```powershell
powershell -NoProfile -Command "Get-CimInstance Win32_ComputerSystem | Select Manufacturer"
```
**Expected:** Dell Inc. (because -NoProfile is stripped)

### Test 3: Malware Simulation
```powershell
powershell -NoProfile -Command "if((Get-CimInstance Win32_ComputerSystem).Manufacturer -match 'VMware'){ exit 0 } else { exit 1 }"; echo $LASTEXITCODE
```
**Expected:** 1 (no VM detected)

### Test 4: Your Actual Malware
```batch
C:\Users\dev-alpha.QUANTUM\AppData\Local\Temp\temp\Z4kzp5ECtD5kBJCt.bat
```
**Expected:** Second stage executes!

---

## Troubleshooting

### Issue: "Real PowerShell not found"
**Solution:** 
- Deployment didn't complete
- Run `Deploy-PowerShellWrapper.ps1` again

### Issue: Still showing VMware
**Solution:**
- Check if wrapper is actually running: `Get-Process powershell | Select Path`
- Verify `STRIP_NOPROFILE = true` in source
- Recompile and redeploy

### Issue: PowerShell won't start
**Solution:**
- Rollback immediately: `.\Rollback-PowerShellWrapper.ps1`
- Check Event Viewer for errors
- Verify wrapper compiled as x64, not x86

### Issue: Malware still exits
**Solution:**
- Malware may use other VM detection methods (registry, files, etc.)
- Enable logging: Set `LOG_ENABLED = true`, recompile, check logs
- Verify your CimD module is working: `Get-Module CimD`

---

## Enable Logging for Debugging

1. Edit `PowerShellWrapper.cs`:
   ```csharp
   const bool LOG_ENABLED = true;
   ```

2. Recompile:
   ```batch
   BUILD-WRAPPER.bat
   ```

3. Redeploy:
   ```powershell
   .\Deploy-PowerShellWrapper.ps1
   ```

4. Run tests, then check logs:
   ```powershell
   Get-Content "C:\ProgramData\Quantum Research\Logs\powershell-wrapper.log" -Tail 20
   ```

**Log output shows:**
- When wrapper is called
- Arguments received
- Arguments stripped
- DLL load success/failure
- Calls to real PowerShell

---

## Rollback

If anything goes wrong:

```powershell
.\Rollback-PowerShellWrapper.ps1
```

This:
1. Removes the wrapper
2. Restores `powershell_real.exe` to `powershell.exe`
3. Tests that PowerShell works normally

---

## Files Provided

**Source & Build:**
- **PowerShellWrapper.cs** - C# source code
- **BUILD-WRAPPER.bat** - Compilation script

**Deployment:**
- **Deploy-PowerShellWrapper.ps1** - Installation
- **Test-PowerShellWrapper.ps1** - Testing suite
- **Rollback-PowerShellWrapper.ps1** - Removal

**Documentation:**
- **POWERSHELL-WRAPPER-GUIDE.md** - This file

---

## Security Considerations

⚠️ **This modifies system files** - Only use in research/honeypot environments  
⚠️ **Windows Update** - May restore original PowerShell, requiring redeployment  
⚠️ **AV/EDR** - May flag wrapper as suspicious (add exclusion if needed)  
⚠️ **Backups exist** - Multiple backups created automatically  

---

## Advantages Over Other Solutions

| Solution | System-Wide | No Config Needed | Easy Rollback | Performance |
|----------|-------------|------------------|---------------|-------------|
| **PowerShell Wrapper** | ✅ | ✅ | ✅ | ⚡ Fast |
| Process Monitor | ❌ | ❌ | N/A | ⚡ Fast |
| AppInit_DLLs | ✅ | ❌ | ✅ | ⚡ Fast |
| DLL Replacement | ✅ | ❌ | ⚠️ Risky | ⚡ Fast |
| Detours Hook | ❌ | ❌ | N/A | ⚡ Fast |

---

## Quick Reference

**Compile:**
```batch
BUILD-WRAPPER.bat
```

**Deploy:**
```powershell
.\Deploy-PowerShellWrapper.ps1
```

**Test:**
```powershell
.\Test-PowerShellWrapper.ps1
```

**Rollback:**
```powershell
.\Rollback-PowerShellWrapper.ps1
```

**Run Malware:**
```batch
C:\path\to\your-malware.bat
```

---

## For Your Specific Malware

```batch
REM After deployment, just run it normally:
C:\Users\dev-alpha.QUANTUM\AppData\Local\Temp\temp\Z4kzp5ECtD5kBJCt.bat
```

Every PowerShell it spawns will:
1. Load the WMI hook DLL
2. Have -NoProfile stripped (if configured)
3. Load your CimD module (if -NoProfile stripped)
4. Return "Dell Inc." for VM checks

**Your malware should now execute properly!**

---

Ready to deploy? Start with `BUILD-WRAPPER.bat`!

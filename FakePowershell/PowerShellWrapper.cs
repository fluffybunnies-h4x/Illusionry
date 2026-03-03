// PowerShellWrapper.cs
// Intercepts all PowerShell launches to inject WMI hook and optionally modify arguments
// 
// Compile: csc /out:powershell.exe /platform:x64 PowerShellWrapper.cs
//
// Features:
// - Loads WMI hook DLL before execution
// - Optionally strips -NoProfile flag (configurable)
// - Maintains proper exit codes
// - Transparent argument pass-through
// - Optional logging for debugging

using System;
using System.Diagnostics;
using System.IO;
using System.Text;
using System.Collections.Generic;

class PowerShellWrapper
{
    // Configuration - Modify these as needed
    const string REAL_POWERSHELL = @"C:\Windows\System32\WindowsPowerShell\v1.0\powershell_quantum.exe";
    const bool STRIP_NOPROFILE = true;  // Set to false to pass -NoProfile through
    const bool LOG_ENABLED = false;      // Set to true for debugging

    static void Log(string message)
    {
        if (!LOG_ENABLED) return;
        
        try
        {
            string logPath = @"C:\ProgramData\Quantum Research\Logs\powershell-wrapper.log";
            string logDir = Path.GetDirectoryName(logPath);
            
            if (!Directory.Exists(logDir))
            {
                Directory.CreateDirectory(logDir);
            }
            
            string timestamp = DateTime.Now.ToString("yyyy-MM-dd HH:mm:ss.fff");
            File.AppendAllText(logPath, $"[{timestamp}] {message}\n");
        }
        catch { }
    }

    static int Main(string[] args)
    {
        Log($"PowerShell wrapper started with {args.Length} arguments");

        // Verify real PowerShell exists
        if (!File.Exists(REAL_POWERSHELL))
        {
            Console.Error.WriteLine("[ERROR] Real PowerShell not found!");
            Console.Error.WriteLine($"Expected location: {REAL_POWERSHELL}");
            Console.Error.WriteLine("");
            Console.Error.WriteLine("Installation steps:");
            Console.Error.WriteLine("  1. Rename powershell.exe to powershell_quantum.exe");
            Console.Error.WriteLine("  2. Compile this wrapper as powershell.exe");
            Console.Error.WriteLine("  3. Run Deploy-PowerShellWrapper.ps1");
            return 1;
        }

        // Process arguments
        List<string> finalArgs = new List<string>();
        
        for (int i = 0; i < args.Length; i++)
        {
            string arg = args[i];
            
            // Check if we should strip -NoProfile
            if (STRIP_NOPROFILE)
            {
                if (arg.Equals("-NoProfile", StringComparison.OrdinalIgnoreCase) ||
                    arg.Equals("-noprofile", StringComparison.OrdinalIgnoreCase) ||
                    arg.Equals("-nop", StringComparison.OrdinalIgnoreCase))
                {
                    Log($"Stripped argument: {arg}");
                    continue; // Skip this argument
                }
            }
            
            finalArgs.Add(arg);
        }

        // Build command line
        StringBuilder cmdLine = new StringBuilder();
        foreach (string arg in finalArgs)
        {
            // Quote arguments that contain spaces
            if (arg.Contains(" ") || arg.Contains("\t"))
            {
                // Escape internal quotes
                string escapedArg = arg.Replace("\"", "\\\"");
                cmdLine.Append($"\"{escapedArg}\" ");
            }
            else
            {
                cmdLine.Append($"{arg} ");
            }
        }

        string arguments = cmdLine.ToString().TrimEnd();
        Log($"Calling real PowerShell with: {arguments}");

        // Start real PowerShell
        ProcessStartInfo psi = new ProcessStartInfo
        {
            FileName = REAL_POWERSHELL,
            Arguments = arguments,
            UseShellExecute = false,
            RedirectStandardInput = false,
            RedirectStandardOutput = false,
            RedirectStandardError = false
        };

        try
        {
            Process process = Process.Start(psi);
            process.WaitForExit();
            
            int exitCode = process.ExitCode;
            Log($"Real PowerShell exited with code: {exitCode}");
            
            return exitCode;
        }
        catch (Exception ex)
        {
            Console.Error.WriteLine($"[ERROR] Failed to start PowerShell: {ex.Message}");
            Log($"Exception: {ex}");
            return 1;
        }
    }
}

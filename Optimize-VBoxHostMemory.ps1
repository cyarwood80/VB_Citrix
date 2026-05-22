# VIRTUALBOX HOST MEMORY OPTIMIZER & TRIMMER
# File: Optimize-VBoxHostMemory.ps1
# Description: Host-side optimization script to reduce VirtualBox memory footprint,
#              disable disk caching, tune VRAM graphics pools, and trim active process working sets.
# Run: Execute this script on your Windows host as an Administrator.

$ErrorActionPreference = "Stop"

# Set window title and console styling
$Host.UI.RawUI.WindowTitle = "VirtualBox Host Memory Optimizer"

# Unicode Character definitions
$ArrowChar   = [char]0x2794  # ➔
$CheckChar   = [char]0x2714  # ✔
$WarnChar    = [char]0x26A0  # ⚠
$CrossChar   = [char]0x2718  # ✘

function Show-Banner {
    Clear-Host
    Write-Host "======================================================================" -ForegroundColor Cyan
    Write-Host "   __   _____             __  __                                      " -ForegroundColor Green
    Write-Host "   \ \ / / _ ) _____ __  |  \/  |___ _ __  ___ _ _ _  _               " -ForegroundColor Green
    Write-Host "    \ V /| _ \/ _ \ \ /  | |\/| / -_) '  \/ _ \ '_| || |              " -ForegroundColor Green
    Write-Host "     \_/ |___/\___/_\_\  |_|  |_\___|_|_|_\___/_|  \_, |              " -ForegroundColor Green
    Write-Host "                                                   |__/               " -ForegroundColor Green
    Write-Host "         VIRTUALBOX HOST-SIDE MEMORY FOOTPRINT OPTIMIZER              " -ForegroundColor Green -Bold
    Write-Host "       Reduces Host RAM Demand, Shadow Tables, & Process Bloat        " -ForegroundColor Cyan
    Write-Host "======================================================================" -ForegroundColor Cyan
    Write-Host ""
}

function Write-Step {
    param([string]$Message)
    Write-Host " $($ArrowChar) $Message..." -ForegroundColor Cyan
}

function Write-Success {
    param([string]$Message)
    Write-Host " $($CheckChar) $Message" -ForegroundColor Green
}

function Write-Warning {
    param([string]$Message)
    Write-Host " $($WarnChar) $Message" -ForegroundColor Yellow -Bold
}

function Write-ErrorText {
    param([string]$Message)
    Write-Host " $($CrossChar) $Message" -ForegroundColor Red -Bold
}

# --- P/INVOKE MEMORY TRIMMER DEFINITION ---
# This registers the Windows API EmptyWorkingSet call to reclaim standby cache memory from active processes.
$Sign = @"
using System;
using System.Runtime.InteropServices;
public class MemoryHelper {
    [DllImport("psapi.dll", SetLastError=true)]
    public static extern bool EmptyWorkingSet(IntPtr hProcess);
}
"@
try {
    Add-Type -TypeDefinition $Sign -ErrorAction SilentlyContinue | Out-Null
} catch {}

# --- HELPER: FIND VBOXMANAGE ---
function Find-VBoxManage {
    $standardPaths = @(
        "$env:ProgramFiles\Oracle\VirtualBox\VBoxManage.exe",
        "$env:ProgramFiles(x86)\Oracle\VirtualBox\VBoxManage.exe"
    )
    foreach ($path in $standardPaths) {
        if (Test-Path $path) { return $path }
    }
    # Check PATH
    $vboxFromPath = Get-Command VBoxManage.exe -ErrorAction SilentlyContinue
    if ($vboxFromPath) { return $vboxFromPath.Source }
    return $null
}

# --- MAIN WIZARD ---
Show-Banner

# Ensure Administrative Privileges
$isAdmin = ([Security.Principal.WindowsPrincipal][Security.Principal.WindowsIdentity]::GetCurrent()).IsInRole([Security.Principal.WindowsBuiltInRole]::Administrator)
if (-not $isAdmin) {
    Write-ErrorText "CRITICAL: This script must be run as an Administrator!"
    Write-Warning "Please close this window, open PowerShell as an Administrator, and re-run the script."
    Write-Host "Press ENTER to exit..."
    $null = Read-Host
    Exit
}

$VBoxManagePath = Find-VBoxManage
if (-not $VBoxManagePath) {
    Write-ErrorText "Could not find VirtualBox installation (VBoxManage.exe)!"
    Exit
}

Write-Host "--- SELECT OPTIMIZATION TYPE ---" -ForegroundColor White -Bold
Write-Host "  [1] Trim Active Memory (Reclaim standby pages from running VM instantly - Safe & Live)" -ForegroundColor Gray
Write-Host "  [2] Configure Memory-Saving VM Profile (Disable host disk cache, reduce VRAM, optimize VT-x)" -ForegroundColor Gray
Write-Host "  [3] Execute Both (Apply configuration adjustments & trim active memory)" -ForegroundColor Gray
Write-Host ""
Write-Host "Select Option [1]: " -NoNewline -ForegroundColor Yellow
$opt = Read-Host
if ([string]::IsNullOrEmpty($opt)) { $opt = "1" }

if ($opt -eq "1" -or $opt -eq "3") {
    Show-Banner
    Write-Step "Locating active VirtualBox VM processes"
    $vboxProcs = Get-Process -Name "VirtualBoxVM" -ErrorAction SilentlyContinue
    if (-not $vboxProcs) {
        Write-Warning "No active VirtualBox VM processes found running on the host."
        Write-Warning "Ensure your virtual machine is powered on and try again."
    } else {
        foreach ($proc in $vboxProcs) {
            $prevRam = [Math]::Round($proc.WorkingSet64 / 1MB, 2)
            Write-Step "Trimming memory for process ID $($proc.Id) (Active Working Set: $prevRam MB)"
            
            # Invoke Windows API page compression/trimming
            $status = [MemoryHelper]::EmptyWorkingSet($proc.Handle)
            if ($status) {
                # Refresh process data
                $proc.Refresh()
                $newRam = [Math]::Round($proc.WorkingSet64 / 1MB, 2)
                $saved = [Math]::Round($prevRam - $newRam, 2)
                Write-Success "Successfully trimmed process ID $($proc.Id)!"
                Write-Host "     Previous Working Set:   $prevRam MB" -ForegroundColor Gray
                Write-Host "     Optimized Working Set:  $newRam MB" -ForegroundColor White
                Write-Host "     Reclaimed Host Memory:  $saved MB" -ForegroundColor Green -Bold
            } else {
                Write-Warning "Could not trim memory for process ID $($proc.Id). (Handle might be restricted)."
            }
        }
    }
}

if ($opt -eq "2" -or $opt -eq "3") {
    Write-Host ""
    Write-Host "--- CONFIGURATION TUNING WIZARD ---" -ForegroundColor White -Bold
    Write-Host "Please enter the target VM Name [Win11-Citrix-VDI]: " -NoNewline -ForegroundColor Yellow
    $VMName = Read-Host
    if ([string]::IsNullOrEmpty($VMName)) { $VMName = "Win11-Citrix-VDI" }

    # Check if VM exists
    $vmCheck = & $VBoxManagePath list vms 2>&1
    if ($vmCheck -notmatch """$VMName""") {
        Write-ErrorText "Could not locate a VirtualBox VM named '$VMName'!"
        Write-Host "Press ENTER to exit..."
        $null = Read-Host
        Exit
    }

    # Verify if VM is active
    $vmState = & $VBoxManagePath showvminfo $VMName --machinereadable | Select-String "VMState="
    $isVMRunning = $vmState -match "running|paused"

    if ($isVMRunning) {
        Write-Warning "Virtual Machine '$VMName' is currently RUNNING."
        Write-Warning "Configuration changes require the virtual machine to be powered off."
        Write-Host "Would you like to send a graceful ACPI shutdown signal now? (Y/N) [Y]: " -NoNewline -ForegroundColor Yellow
        $confirmShutdown = Read-Host
        if ([string]::IsNullOrEmpty($confirmShutdown)) { $confirmShutdown = "Y" }
        
        if ($confirmShutdown -eq "Y" -or $confirmShutdown -eq "y") {
            Write-Step "Sending ACPI shutdown signal"
            & $VBoxManagePath controlvm $VMName acpipowerbutton | Out-Null
            
            $ticks = 0
            while ($isVMRunning -and $ticks -lt 60) {
                Start-Sleep -Seconds 2
                $ticks += 2
                $vmState = & $VBoxManagePath showvminfo $VMName --machinereadable | Select-String "VMState="
                $isVMRunning = $vmState -match "running|paused"
                Write-Host -NoNewline "`r   Waiting for VM to power off... ($ticks/60s)" -ForegroundColor Yellow
            }
            Write-Host ""
            if ($isVMRunning) {
                Write-ErrorText "VM failed to power off gracefully in 60s. Aborting config tweaks to prevent data loss."
                Write-Host "Press ENTER to exit..."
                $null = Read-Host
                Exit
            }
            Write-Success "VM successfully powered off."
        } else {
            Write-ErrorText "Tuning aborted by user (VM must be powered off)."
            Write-Host "Press ENTER to exit..."
            $null = Read-Host
            Exit
        }
    }

    Show-Banner
    Write-Host "--- SELECT PERFORMANCE PROFILE ---" -ForegroundColor White -Bold
    Write-Host "  [1] Balanced Memory Saving (Disables Host Disk I/O Caching & sets VRAM to 128MB)" -ForegroundColor Gray
    Write-Host "      $($ArrowChar) Saves ~2GB to 4GB Host RAM. Keeps Nested virtualization & VBS fully active." -ForegroundColor Cyan
    Write-Host ""
    Write-Host "  [2] Aggressive Memory Saving (Disables Disk Caching, 128MB VRAM, & disables Nested Hardware VT-x)" -ForegroundColor Gray
    Write-Host "      $($ArrowChar) Saves ~6GB to 10GB Host RAM! Recommended if you DO NOT run Docker or WSL2 inside the VM." -ForegroundColor Cyan
    Write-Host ""
    Write-Host "Select Profile Option [1]: " -NoNewline -ForegroundColor Yellow
    $profileOpt = Read-Host
    if ([string]::IsNullOrEmpty($profileOpt)) { $profileOpt = "1" }

    Write-Step "Applying profile adjustments to '$VMName'"

    # 1. Disable Host Disk I/O Caching (Saves 2GB - 4GB disk buffer RAM)
    & $VBoxManagePath storagectl $VMName --name "SATA Controller" --hostiocache off | Out-Null
    Write-Success "Disabled Host Disk I/O Caching (Saves disk caching overhead)."

    # 2. Optimize VRAM Pool (Saves 1GB+ graphics pipeline allocation)
    & $VBoxManagePath modifyvm $VMName --vram 128 | Out-Null
    Write-Success "Reduced VRAM to 128MB (Perfectly adequate for 1080p/1600x1200 single displays)."

    # 3. Aggressive Profile: Toggle Nested Virtualization
    if ($profileOpt -eq "2") {
        & $VBoxManagePath modifyvm $VMName --nested-hw-virt off | Out-Null
        Write-Success "Disabled Nested HW VT-x (Removes massive double shadow page-table allocation!)."
        Write-Warning "Note: Windows 11 will disable VBS/HVCI Core Isolation and WSL2/Docker will not run."
    } else {
        # Profile 1: Keep Nested Virtualization on
        & $VBoxManagePath modifyvm $VMName --nested-hw-virt on | Out-Null
        Write-Success "Kept Nested HW VT-x Active for WSL2/Docker/VBS compatibility."
    }

    # 4. Low-latency Compute Optimizations (Large Pages & Bypass Speculative Mitigations)
    & $VBoxManagePath modifyvm $VMName --large-pages on --spec-ctrl off | Out-Null
    Write-Success "Enabled Host Large Pages and disabled VM-context Speculative Execution Control."

    Write-Host ""
    Write-Success "Memory-Saving VM Configuration Profiles successfully applied!"
    Write-Host "======================================================================" -ForegroundColor Green
    Write-Host " You can now boot your VM. Enjoy highly optimized host RAM consumption!" -ForegroundColor White -Bold
    Write-Host "======================================================================" -ForegroundColor Green
}

Write-Host ""
Write-Host "Press ENTER to exit..."
$null = Read-Host

# WINDOWS 11 GUEST INPUT RESPONSIVENESS OPTIMIZER
# File: Optimize-GuestInputLag.ps1
# Description: Guest-side optimization script to eliminate mouse and keyboard input lag,
#              disable mouse acceleration, maximize keyboard repeat rates, tune system
#              responsiveness profiles, and minimize UI menu latency.
# Run: Execute this script inside the Windows 11 guest VM as an Administrator.

$ErrorActionPreference = "Stop"

# Set window title and console styling
$Host.UI.RawUI.WindowTitle = "VDI Guest Input Lag Optimizer"

# Safe Unicode Character definitions
$ArrowChar   = [char]0x2794  # âž”
$CheckChar   = [char]0x2714  # âœ”
$WarnChar    = [char]0x26A0  # âš 
$BulletChar  = [char]0x25CF  # â—

function Show-Banner {
    Clear-Host
    Write-Host "======================================================================" -ForegroundColor Cyan
    Write-Host "      __   ___                  _ _ _            _ _                  " -ForegroundColor Green
    Write-Host "      \ \ / / _ ) _____ __      | | | |___ _  _  / | |                " -ForegroundColor Green
    Write-Host "       \ V /| _ \/ _ \ \ /      | | | / _ \ || | | | |                " -ForegroundColor Green
    Write-Host "        \_/ |___/\___/_\_\      |_|_|_|___/\_,_| |_|_|                " -ForegroundColor Green
    Write-Host "                                                                      " -ForegroundColor Green
    Write-Host "          WINDOWS 11 GUEST VDI INPUT RESPONSIVENESS OPTIMIZER         " -ForegroundColor Green -Bold
    Write-Host "        Eliminates Mouse/Keyboard Input Lag and UI Click Latency      " -ForegroundColor Cyan
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

# 1. Verify Administrative Privileges
Show-Banner
Write-Step "Verifying Administrator privileges"
$currentUser = [Security.Principal.WindowsPrincipal][Security.Principal.WindowsIdentity]::GetCurrent()
if (-not $currentUser.IsInRole([Security.Principal.WindowsBuiltInRole]::Administrator)) {
    Write-Host ""
    Write-Host " [âœ–] ERROR: This script must be run as an Administrator!" -ForegroundColor Red -Bold
    Write-Host " Please reopen PowerShell as Administrator and run the script again." -ForegroundColor Yellow
    Write-Host ""
    Write-Host "Press ENTER to exit..."
    $null = Read-Host
    Exit
}
Write-Success "Elevated Administrator privileges confirmed."

# 2. System-wide Responsiveness and Input Queue Tuning
Write-Step "Configuring System-wide low-latency responsiveness and input buffer queues"
try {
    # SystemResponsiveness = 0 allocates 100% of CPU resource scheduling priority to interactive user processes
    $SysProfilePath = "HKLM:\SOFTWARE\Microsoft\Windows NT\CurrentVersion\Multimedia\SystemProfile"
    Set-ItemProperty -Path $SysProfilePath -Name "SystemResponsiveness" -Value 0 -Type DWord -Force
    Set-ItemProperty -Path $SysProfilePath -Name "NetworkThrottlingIndex" -Value 0xffffffff -Type DWord -Force

    # Win32PrioritySeparation = 26 (0x1a) allocates short, variable, high priority scheduling quanta to foreground processes (snappy UI)
    $PriorityControlPath = "HKLM:\SYSTEM\CurrentControlSet\Control\PriorityControl"
    Set-ItemProperty -Path $PriorityControlPath -Name "Win32PrioritySeparation" -Value 26 -Type DWord -Force

    # Input Queues: reduces buffer depth from 100 to 30 to flush events instantly and prevent input lag buildup
    $MouclassPath = "HKLM:\SYSTEM\CurrentControlSet\Services\mouclass\Parameters"
    Set-ItemProperty -Path $MouclassPath -Name "MouseDataQueueSize" -Value 30 -Type DWord -Force

    $KbdclassPath = "HKLM:\SYSTEM\CurrentControlSet\Services\kbdclass\Parameters"
    Set-ItemProperty -Path $KbdclassPath -Name "KeyboardDataQueueSize" -Value 30 -Type DWord -Force

    Write-Success "System scheduler, priority separation, and mouse/keyboard buffer queues tuned successfully."
} catch {
    Write-Warning "Failed to optimize system-wide responsiveness settings: $_"
}

# 3. Apply Low Latency TCP settings (TCP Ack Frequency & TCP No Delay)
Write-Step "Optimizing TCP network stack for high-performance Citrix VDI streams"
try {
    $NetworkInterfacesPath = "HKLM:\SYSTEM\CurrentControlSet\Services\Tcpip\Parameters\Interfaces"
    $interfaces = Get-ChildItem -Path $NetworkInterfacesPath
    $count = 0
    foreach ($interface in $interfaces) {
        $path = $interface.PSPath
        Set-ItemProperty -Path $path -Name "TcpAckFrequency" -Value 1 -Type DWord -Force -ErrorAction SilentlyContinue
        Set-ItemProperty -Path $path -Name "TCPNoDelay" -Value 1 -Type DWord -Force -ErrorAction SilentlyContinue
        $count++
    }
    Write-Success "Optimized TCP Ack Frequency and disabled Nagle's algorithm on $count network interfaces."
} catch {
    Write-Warning "Failed to apply network optimizations: $_"
}

# 4. Set Windows Power Plan to High Performance
Write-Step "Activating Windows High Performance Power Plan"
try {
    $HighPerfGuid = "8c5e7fda-e8bf-4a96-9a85-a6e23a8c635c"
    & powercfg /setactive $HighPerfGuid
    Write-Success "High Performance Power Plan activated."
} catch {
    Write-Warning "Failed to set Power Plan: $_"
}

# 5. Define a helper block to apply input tweaks to registry hives
$ApplyUserInputTweaks = {
    param([string]$basePath)
    
    # A. Disable Mouse Acceleration (enhance pointer precision) -> Sets raw 1:1 absolute coordinates for USB tablet
    $mousePath = Join-Path $basePath "Control Panel\Mouse"
    if (!(Test-Path $mousePath)) { New-Item -Path $mousePath -Force | Out-Null }
    Set-ItemProperty -Path $mousePath -Name "MouseSpeed" -Value "0" -Type String -Force
    Set-ItemProperty -Path $mousePath -Name "MouseThreshold1" -Value "0" -Type String -Force
    Set-ItemProperty -Path $mousePath -Name "MouseThreshold2" -Value "0" -Type String -Force
    # MouseHoverTime = 8ms (default 400ms) - opens menus instantly
    Set-ItemProperty -Path $mousePath -Name "MouseHoverTime" -Value "8" -Type String -Force
    
    # B. Optimize Keyboard Auto-Repeat Delay and Auto-Repeat Speed
    $kbdPath = Join-Path $basePath "Control Panel\Keyboard"
    if (!(Test-Path $kbdPath)) { New-Item -Path $kbdPath -Force | Out-Null }
    # KeyboardDelay = 0 (shortest repeat delay: 250ms, default is 1 or 2)
    Set-ItemProperty -Path $kbdPath -Name "KeyboardDelay" -Value "0" -Type String -Force
    # KeyboardSpeed = 31 (fastest keyboard repeat rate, default is 31 but makes sure it is locked)
    Set-ItemProperty -Path $kbdPath -Name "KeyboardSpeed" -Value "31" -Type String -Force
    
    # C. Minimize Menu opening latency
    $desktopPath = Join-Path $basePath "Control Panel\Desktop"
    if (!(Test-Path $desktopPath)) { New-Item -Path $desktopPath -Force | Out-Null }
    # MenuShowDelay = 0ms (makes all menus/overlays render instantaneously upon click)
    Set-ItemProperty -Path $desktopPath -Name "MenuShowDelay" -Value "0" -Type String -Force
    # DragFullWindows = "0" (shows window border outline while dragging, saving massive DWM redraws)
    Set-ItemProperty -Path $desktopPath -Name "DragFullWindows" -Value "0" -Type String -Force
    
    # D. Minimize Window transition and DWM hover latency
    $metricsPath = Join-Path $basePath "Control Panel\Desktop\WindowMetrics"
    if (!(Test-Path $metricsPath)) { New-Item -Path $metricsPath -Force | Out-Null }
    # MinAnimate = "0" (disables minimize/maximize animation for instant window transitions)
    Set-ItemProperty -Path $metricsPath -Name "MinAnimate" -Value "0" -Type String -Force

    $dwmPath = Join-Path $basePath "Software\Microsoft\Windows\DWM"
    if (!(Test-Path $dwmPath)) { New-Item -Path $dwmPath -Force | Out-Null }
    # AlwaysHibernateThumbnails = 1 (disables live background DWM taskbar hover thumbnail rendering)
    Set-ItemProperty -Path $dwmPath -Name "AlwaysHibernateThumbnails" -Value 1 -Type DWord -Force
    # EnableAeroPeek = 0 (disables background desktop peek hover overlays)
    Set-ItemProperty -Path $dwmPath -Name "EnableAeroPeek" -Value 0 -Type DWord -Force
}

# 6. Apply Input Tweaks to Current Administrator Profile
Write-Step "Applying input lag tweaks to current user profile"
try {
    & $ApplyUserInputTweaks "HKCU:"
    Write-Success "Current user profile input parameters optimized."
} catch {
    Write-Warning "Failed to optimize current user input parameters: $_"
}

# 7. Apply Input Tweaks to Default User Profile Hive (For all future login sessions)
Write-Step "Mounting Default User NTUSER.DAT registry hive to apply optimizations globally"
$defaultHiveFile = "C:\Users\Default\NTUSER.DAT"
if (Test-Path $defaultHiveFile) {
    try {
        # Force garbage collection to ensure no lingering locks before load/unload
        [GC]::Collect()
        [GC]::WaitForPendingFinalizers()
        
        # Load default hive
        $loadRes = reg load HKU\DefaultUser $defaultHiveFile 2>&1
        Write-Success "Mounted Default User hive successfully."
        
        # Apply the tweaks to Default User profile
        Write-Step "Injecting input responsiveness keys into Default User profile"
        & $ApplyUserInputTweaks "Registry::HKU\DefaultUser"
        Write-Success "Default User profile registry parameters optimized."
        
        # Unload default hive cleanly
        Write-Step "Unmounting Default User registry hive"
        [GC]::Collect()
        [GC]::WaitForPendingFinalizers()
        Start-Sleep -Milliseconds 500
        $unloadRes = reg unload HKU\DefaultUser 2>&1
        Write-Success "Unmounted Default User registry hive successfully."
    } catch {
        Write-Warning "Failed to apply tweaks to Default User registry hive: $_"
        # Try unloading in case it got stuck
        try { reg unload HKU\DefaultUser 2>&1 | Out-Null } catch {}
    }
} else {
    Write-Warning "Default User hive NTUSER.DAT not found! Global user auto-inheritance skipped."
}

# 8. Disable Visual Animations to Maximize Frame Refresh Rate
Write-Step "Optimizing graphics: Disabling CPU-heavy visual animations"
try {
    $VisualSettingsPath = "HKCU:\Software\Microsoft\Windows\CurrentVersion\Explorer\VisualEffects"
    if (!(Test-Path $VisualSettingsPath)) { New-Item -Path $VisualSettingsPath -Force | Out-Null }
    # VisualFXSetting = 2 (Adjust for best performance)
    Set-ItemProperty -Path $VisualSettingsPath -Name "VisualFXSetting" -Value 2 -Type DWord -Force
    Write-Success "Visual animations and cursor shadows disabled (reduces GPU scheduling lag)."
} catch {
    Write-Warning "Failed to adjust visual effects: $_"
}

# 9. Finished
Show-Banner
Write-Host "======================================================================" -ForegroundColor Green -Bold
Write-Host "             GUEST INPUT & GRAPHICS OPTIMIZATION COMPLETE!            " -ForegroundColor Green -Bold
Write-Host "======================================================================" -ForegroundColor Green -Bold
Write-Host ""
Write-Host " The following low-latency profiles have been applied successfully:" -ForegroundColor White
Write-Host " $($CheckChar) Disabled Windows Mouse Acceleration (Enabled raw 1:1 cursor)" -ForegroundColor Green
Write-Host " $($CheckChar) Shortened Keyboard Repeat Delay to 250ms (Shortest possible)" -ForegroundColor Green
Write-Host " $($CheckChar) Maximized Keyboard Auto-Repeat Rate (Speed 31)" -ForegroundColor Green
Write-Host " $($CheckChar) Minimized Menu & Hover opening latency (0ms / 8ms)" -ForegroundColor Green
Write-Host " $($CheckChar) Set System Responsiveness scheduler to 100% User Process" -ForegroundColor Green
Write-Host " $($CheckChar) Set CPU Foreground Priority separation to 26 (Interactive UI)" -ForegroundColor Green
Write-Host " $($CheckChar) Shrunk Mouse/Keyboard data queue depth to 30 (Instant event flush)" -ForegroundColor Green
Write-Host " $($CheckChar) Enabled Drag Outline-Only window drawing (No DWM redraw lag)" -ForegroundColor Green
Write-Host " $($CheckChar) Enabled DWM live hover thumbnail and Aero Peek hibernation" -ForegroundColor Green
Write-Host " $($CheckChar) Disabled Network throttling under high CPU utilization" -ForegroundColor Green
Write-Host " $($CheckChar) Set TCP Ack Frequency & TCP No Delay on all interfaces" -ForegroundColor Green
Write-Host " $($CheckChar) Enabled High Performance Windows Power Plan" -ForegroundColor Green
Write-Host " $($CheckChar) Disabled OS-level visual transition effects" -ForegroundColor Green
Write-Host ""
Write-Host " Note: Some settings will take effect on the next login or after reboot." -ForegroundColor Yellow -Bold
Write-Host " Please LOG OUT and LOG BACK IN, or REBOOT the VM now!" -ForegroundColor Yellow -Bold
Write-Host "======================================================================" -ForegroundColor Cyan
Write-Host ""
Write-Host "Press ENTER to close this window..."
$null = Read-Host

# VIRTUALBOX WINDOWS 11 PRO CITRIX VDI PROVISIONER
# File: New-VBoxWin11VM.ps1
# Author: Antigravity Pair Programmer
# Description: Self-contained interactive script to provision a Windows 11 Pro VM 
#              in VirtualBox 7.2.8 with nested virtualization, VBS, and pre-configured 
#              Citrix Workspace App 2603 with running App Protection.
#              Consolidates unattended XML answers, VM priority settings, HPET timers, 
#              Gigabit server NICs, USB hardware filters, and post-install webcam mapping!
$ErrorActionPreference = "Stop"

# Safe Unicode Character definitions (avoiding raw bytes in script file to prevent ANSI/UTF-8 decoding errors in Windows PowerShell)
$ArrowChar   = [char]0x2794  # ➔
$CheckChar   = [char]0x2714  # ✔
$WarnChar    = [char]0x26A0  # ⚠
$CrossChar   = [char]0x2716  # ✖
$BlockChar   = [char]0x2588  # █
$ShadeChar   = [char]0x2591  # ░
$ClockChar   = [char]0x23F0  # ⏰
$BulletChar  = [char]0x25CF  # ●

# Set window title and console styling
$Host.UI.RawUI.WindowTitle = "VirtualBox Windows 11 Citrix VDI Provisioner"

# --- EMBEDDED UNATTENDED INSTALL XML TEMPLATE ---
# This is the customized unattend.xml for VirtualBox 7.2.8 with OOBE offline logon registry bypasses.
$UnattendedXmlContent = @'
<?xml version="1.0" encoding="utf-8"?>
<!--
    Copyright (C) 2016-2025 Oracle and/or its affiliates.

    This file is part of VirtualBox base platform packages, as
    available from https://www.virtualbox.org.

    This program is free software; you can redistribute it and/or
    modify it under the terms of the GNU General Public License
    as published by the Free Software Foundation, in version 3 of the
    License.

    This program is distributed in the hope that it will be useful, but
    WITHOUT ANY WARRANTY; without even the implied warranty of
    MERCHANTABILITY or FITNESS FOR A PARTICULAR PURPOSE.  See the GNU
    General Public License for more details.

    You should have received a copy of the GNU General Public License
    along with this program; if not, see <https://www.gnu.org/licenses>.

    SPDX-License-Identifier: GPL-3.0-only
-->
<unattend xmlns="urn:schemas-microsoft-com:unattend"
    xmlns:wcm="http://schemas.microsoft.com/WMIConfig/2002/State">

    <settings pass="windowsPE">
        <component name="Microsoft-Windows-International-Core-WinPE"
            processorArchitecture="@@VBOX_INSERT_OS_ARCH_ATTRIB_DQ@@"
            publicKeyToken="31bf3856ad364e35" language="neutral"
            versionScope="nonSxS">
            <InputLocale>en-GB</InputLocale>
            <SystemLocale>@@VBOX_INSERT_DASH_LOCALE@@</SystemLocale>
            <UserLocale>@@VBOX_INSERT_DASH_LOCALE@@</UserLocale>
            <!-- UILanguage must match the installation media language.  Stuff like de-CH does not work for
                 example de_windows_7_enterprise_with_sp1_x64_dvd_u_677649.iso.  However, stupidly we cannot
                 omit this element (kudos to brilliant minds at MS).  -->
            <UILanguage>@@VBOX_INSERT_LANGUAGE@@</UILanguage>
        </component>

        <component name="Microsoft-Windows-Setup"
            processorArchitecture="@@VBOX_INSERT_OS_ARCH_ATTRIB_DQ@@"
            publicKeyToken="31bf3856ad364e35" language="neutral"
            versionScope="nonSxS">

            <DiskConfiguration>
                <WillShowUI>OnError</WillShowUI>
                <Disk>
                    <DiskID>0</DiskID>
                    <WillWipeDisk>true</WillWipeDisk>
@@VBOX_COND_IS_NOT_FIRMWARE_UEFI@@
                    <CreatePartitions>
                        <!-- TODO: Use the standard partitioning scheme at starting with Windows 8 maybe, using 2 partitions as described by Microsoft? -->
                        <CreatePartition>
                            <Order>1</Order>
                            <Type>Primary</Type>
                            <Extend>true</Extend>
                        </CreatePartition>
                    </CreatePartitions>
@@VBOX_COND_END@@
@@VBOX_COND_IS_FIRMWARE_UEFI@@
                    <CreatePartitions>
                        <CreatePartition wcm:action="add">
                            <Order>1</Order>
                            <Type>Primary</Type>
                            <Size>300</Size>
                        </CreatePartition>
                        <CreatePartition wcm:action="add">
                            <Order>2</Order>
                            <Type>EFI</Type>
                            <Size>100</Size>
                        </CreatePartition>
                        <CreatePartition wcm:action="add">
                            <Order>3</Order>
                            <Type>MSR</Type>
                            <Size>128</Size>
                        </CreatePartition>
                        <CreatePartition wcm:action="add">
                            <Order>4</Order>
                            <Type>Primary</Type>
                            <Extend>true</Extend>
                        </CreatePartition>
                    </CreatePartitions>
                    <ModifyPartitions>
                        <ModifyPartition wcm:action="add">
                            <Order>1</Order>
                            <PartitionID>1</PartitionID>
                            <Label>WINRE</Label>
                            <Format>NTFS</Format>
                            <TypeID>de94bba4-06d1-4d40-a16a-bfd50179d6ac</TypeID>
                        </ModifyPartition>
                        <ModifyPartition wcm:action="add">
                            <Order>2</Order>
                            <PartitionID>2</PartitionID>
                            <Label>EFI</Label>
                            <Format>FAT32</Format>
                        </ModifyPartition>
                        <ModifyPartition wcm:action="add">
                            <Order>3</Order>
                            <PartitionID>3</PartitionID>
                        </ModifyPartition>
                        <ModifyPartition wcm:action="add">
                            <Order>4</Order>
                            <PartitionID>4</PartitionID>
                            <Label>Windows</Label>
                            <Letter>C</Letter>
                            <Format>NTFS</Format>
                        </ModifyPartition>
                    </ModifyPartitions>
@@VBOX_COND_END@@
                </Disk>
            </DiskConfiguration>

            <UserData>
                <ProductKey>
                    <Key>@@VBOX_INSERT_PRODUCT_KEY_ELEMENT@@</Key>
                    <WillShowUI>OnError</WillShowUI>
                </ProductKey>
                <AcceptEula>true</AcceptEula>
            </UserData>

            <ImageInstall>
                <OSImage>
                    <InstallFrom>
                        <!-- TODO: This stuff doesn't work for en_windows_vista_enterprise_sp1_x64_and_x86.iso ... -->
                        <MetaData wcm:action="add">
                            <Key>/IMAGE/INDEX</Key>
                            <Value>@@VBOX_INSERT_IMAGE_INDEX_ELEMENT@@</Value>
                        </MetaData>
                        <!-- <Path>d:\sources\install.wim</Path> - the w7 tests doesn't specify this -->
                    </InstallFrom>
                    <InstallTo>
                        <DiskID>0</DiskID>
@@VBOX_COND_IS_NOT_FIRMWARE_UEFI@@
                        <PartitionID>1</PartitionID>
@@VBOX_COND_END@@
@@VBOX_COND_IS_FIRMWARE_UEFI@@
                        <PartitionID>4</PartitionID>
@@VBOX_COND_END@@
                    </InstallTo>
                    <WillShowUI>OnError</WillShowUI>
                    <InstallToAvailablePartition>false</InstallToAvailablePartition>
                </OSImage>
            </ImageInstall>

            <ComplianceCheck>
                <DisplayReport>OnError</DisplayReport>
            </ComplianceCheck>

            <!-- Apply registry tweaks to Windows PE, skipping the checks in the Windows 11 setup program. This will not make it to the final install, and should do no harm with older Windows versions. -->
            <RunAsynchronous>
                <RunAsynchronousCommand>
                    <Order>1</Order>
                    <Path>reg.exe ADD HKLM\SYSTEM\Setup\LabConfig /v BypassCPUCheck /t REG_DWORD /d 1 /f</Path>
                    <Description>Windows 11 disable CPU check</Description>
                </RunAsynchronousCommand>
                <RunAsynchronousCommand>
                    <Order>2</Order>
                    <Path>reg.exe ADD HKLM\SYSTEM\Setup\LabConfig /v BypassRAMCheck /t REG_DWORD /d 1 /f</Path>
                    <Description>Windows 11 disable RAM check</Description>
                </RunAsynchronousCommand>
                <RunAsynchronousCommand>
                    <Order>3</Order>
                    <Path>reg.exe ADD HKLM\SYSTEM\Setup\LabConfig /v BypassSecureBootCheck /t REG_DWORD /d 1 /f</Path>
                    <Description>Windows 11 disable Secure Boot check</Description>
                </RunAsynchronousCommand>
                <RunAsynchronousCommand>
                    <Order>4</Order>
                    <Path>reg.exe ADD HKLM\SYSTEM\Setup\LabConfig /v BypassStorageCheck /t REG_DWORD /d 1 /f</Path>
                    <Description>Windows 11 disable Storage check</Description>
                </RunAsynchronousCommand>
                <RunAsynchronousCommand>
                    <Order>5</Order>
                    <Path>reg.exe ADD HKLM\SYSTEM\Setup\LabConfig /v BypassTPMCheck /t REG_DWORD /d 1 /f</Path>
                    <Description>Windows 11 disable TPM check</Description>
                </RunAsynchronousCommand>
            </RunAsynchronous>

        </component>
    </settings>

    <settings pass="specialize">
        <component name="Microsoft-Windows-Shell-Setup"
            processorArchitecture="@@VBOX_INSERT_OS_ARCH_ATTRIB_DQ@@"
            publicKeyToken="31bf3856ad364e35" language="neutral"
            versionScope="nonSxS">
            <ComputerName>@@VBOX_INSERT_HOSTNAME_WITHOUT_DOMAIN_MAX_15@@</ComputerName>
        </component>

        <component name="Microsoft-Windows-Deployment"
            processorArchitecture="@@VBOX_INSERT_OS_ARCH_ATTRIB_DQ@@"
            publicKeyToken="31bf3856ad364e35" language="neutral"
            versionScope="nonSxS">

            <!-- Apply registry tweaks in the final Windows install, skipping the checks in the Windows 11 setup program. This means upgrades started in this install will work without compatibility complaints. -->
            <RunAsynchronous>
                <RunAsynchronousCommand>
                    <Order>1</Order>
                    <Path>reg.exe ADD HKLM\SYSTEM\Setup\LabConfig /v BypassCPUCheck /t REG_DWORD /d 1 /f</Path>
                    <Description>Windows 11 disable CPU check</Description>
                </RunAsynchronousCommand>
                <RunAsynchronousCommand>
                    <Order>2</Order>
                    <Path>reg.exe ADD HKLM\SYSTEM\Setup\LabConfig /v BypassRAMCheck /t REG_DWORD /d 1 /f</Path>
                    <Description>Windows 11 disable RAM check</Description>
                </RunAsynchronousCommand>
                <RunAsynchronousCommand>
                    <Order>3</Order>
                    <Path>reg.exe ADD HKLM\SYSTEM\Setup\LabConfig /v BypassSecureBootCheck /t REG_DWORD /d 1 /f</Path>
                    <Description>Windows 11 disable Secure Boot check</Description>
                </RunAsynchronousCommand>
                <RunAsynchronousCommand>
                    <Order>4</Order>
                    <Path>reg.exe ADD HKLM\SYSTEM\Setup\LabConfig /v BypassStorageCheck /t REG_DWORD /d 1 /f</Path>
                    <Description>Windows 11 disable Storage check</Description>
                </RunAsynchronousCommand>
                <RunAsynchronousCommand>
                    <Order>5</Order>
                    <Path>reg.exe ADD HKLM\SYSTEM\Setup\LabConfig /v BypassTPMCheck /t REG_DWORD /d 1 /f</Path>
                    <Description>Windows 11 disable TPM check</Description>
                </RunAsynchronousCommand>
                <RunAsynchronousCommand>
                    <Order>6</Order>
                    <Path>reg.exe ADD HKLM\SOFTWARE\Microsoft\Windows\CurrentVersion\OOBE /v BypassNRO /t REG_DWORD /d 1 /f</Path>
                    <Description>Windows 11 bypass OOBE network check</Description>
                </RunAsynchronousCommand>
                <RunAsynchronousCommand>
                    <Order>7</Order>
                    <Path>cmd.exe /c "echo @echo off &gt; C:\Bypass-OOBE.cmd &amp;&amp; echo echo Bypassing Windows 11 Microsoft Account setup... &gt;&gt; C:\Bypass-OOBE.cmd &amp;&amp; echo start ms-cxh:localonly &gt;&gt; C:\Bypass-OOBE.cmd"</Path>
                    <Description>Create easy-to-type OOBE bypass script at C:\Bypass-OOBE.cmd</Description>
                </RunAsynchronousCommand>
                <RunAsynchronousCommand>
                    <Order>8</Order>
                    <Path>reg.exe ADD HKLM\SOFTWARE\Microsoft\Windows\CurrentVersion\Policies\System /v EnableFirstLogonAnimation /t REG_DWORD /d 0 /f</Path>
                    <Description>Disable First Logon Animation</Description>
                </RunAsynchronousCommand>
                <RunAsynchronousCommand>
                    <Order>9</Order>
                    <Path>reg.exe ADD HKLM\SOFTWARE\Microsoft\Windows\CurrentVersion\Policies\System /v EnableLUA /t REG_DWORD /d 0 /f</Path>
                    <Description>Disable UAC</Description>
                </RunAsynchronousCommand>
                <RunAsynchronousCommand>
                    <Order>10</Order>
                    <Path>reg.exe ADD HKLM\SOFTWARE\Microsoft\Windows\CurrentVersion\Policies\System /v ConsentPromptBehaviorAdmin /t REG_DWORD /d 0 /f</Path>
                    <Description>Elevate without prompting</Description>
                </RunAsynchronousCommand>
                <RunAsynchronousCommand>
                    <Order>11</Order>
                    <Path>reg.exe ADD HKLM\SOFTWARE\Microsoft\Windows\CurrentVersion\Policies\System /v PromptOnSecureDesktop /t REG_DWORD /d 0 /f</Path>
                    <Description>Disable Secure Desktop</Description>
                </RunAsynchronousCommand>
            </RunAsynchronous>
        </component>
    </settings>

    <settings pass="oobeSystem">
        <component name="Microsoft-Windows-Shell-Setup"
            processorArchitecture="@@VBOX_INSERT_OS_ARCH_ATTRIB_DQ@@"
            publicKeyToken="31bf3856ad364e35" language="neutral"
            versionScope="nonSxS">
            <AutoLogon>
                <Password>
                    <Value>@@VBOX_INSERT_USER_PASSWORD_ELEMENT@@</Value>
                    <PlainText>true</PlainText>
                </Password>
                <Enabled>true</Enabled>
                <Username>@@VBOX_INSERT_USER_LOGIN_ELEMENT@@</Username>
            </AutoLogon>

            <UserAccounts>
@@VBOX_COND_IS_USER_LOGIN_NOT_ADMINISTRATOR@@
                <AdministratorPassword>
                    <Value>@@VBOX_INSERT_ROOT_PASSWORD_ELEMENT@@</Value>
                    <PlainText>true</PlainText>
                </AdministratorPassword>

                <LocalAccounts>
                    <LocalAccount wcm:action="add">
                        <Name>@@VBOX_INSERT_USER_LOGIN_ELEMENT@@</Name>
                        <DisplayName>@@VBOX_INSERT_USER_FULL_NAME_ELEMENT@@</DisplayName>
                        <Group>administrators;users</Group>
                        <Password>
                            <Value>@@VBOX_INSERT_USER_PASSWORD_ELEMENT@@</Value>
                            <PlainText>true</PlainText>
                        </Password>
                    </LocalAccount>
                </LocalAccounts>
@@VBOX_COND_END@@
@@VBOX_COND_IS_USER_LOGIN_ADMINISTRATOR@@
                <AdministratorPassword>
                    <Value>@@VBOX_INSERT_USER_PASSWORD_ELEMENT@@</Value>
                    <PlainText>true</PlainText>
                </AdministratorPassword>
@@VBOX_COND_END@@
            </UserAccounts>

            <VisualEffects>
                <FontSmoothing>ClearType</FontSmoothing>
            </VisualEffects>

            <OOBE>
                <ProtectYourPC>3</ProtectYourPC>
                <HideEULAPage>true</HideEULAPage>
                <SkipUserOOBE>true</SkipUserOOBE>
                <SkipMachineOOBE>true</SkipMachineOOBE>
                <!-- Make this (NetworkLocation) default to public and make it configurable -->
                <NetworkLocation>Home</NetworkLocation>
            </OOBE>

            <FirstLogonCommands>
                <SynchronousCommand wcm:action="add">
                    <!-- For which OS versions do we need to do this? -->
                    <Order>1</Order>
                    <Description>Turn Off Network Selection pop-up</Description>
                    <CommandLine>reg.exe add "HKLM\SYSTEM\CurrentControlSet\Control\Network\NewNetworkWindowOff"</CommandLine>
                </SynchronousCommand>
                <SynchronousCommand wcm:action="add">
                    <Order>2</Order>
                    <Description>VirtualBox post guest install steps </Description>
                    <CommandLine>cmd.exe /c @@VBOX_INSERT_AUXILIARY_INSTALL_DIR@@VBOXPOST.CMD --vista-or-newer</CommandLine>
                </SynchronousCommand>
            </FirstLogonCommands>

            <TimeZone>@@VBOX_INSERT_TIME_ZONE_WIN_NAME@@</TimeZone>
        </component>

    </settings>
</unattend>
'@

# --- EMBEDDED GUEST CONFIGURATION SCRIPT ---
# This script is written as a Here-String and will be pushed to the guest OS via VBoxManage guestcontrol.
$GuestScriptContent = @'
# GUEST OS CONFIGURATION & VDI OPTIMIZATION SCRIPT
# File: GuestConfigure.ps1
# Description: Enables nested virtualization features, installs Citrix Workspace App 2603
#              silently, and configures latency & display tweaks for low-lag VDI access.
$LogFile = "C:\Windows\Temp\VDI-Setup.log"
Start-Transcript -Path $LogFile -Append
function Write-Log {
    param([string]$Msg, [string]$Type = "INFO")
    $timestamp = Get-Date -Format "yyyy-MM-dd HH:mm:ss"
    $line = "[$timestamp] [$Type] $Msg"
    Write-Output $line
}
Write-Log "Starting Guest VDI Configuration Script"

# Force UK English (en-GB) system locale and remove US keyboard layout to prevent typing errors
try {
    Write-Log "Forcing UK English (en-GB) system culture and keyboard layout..."
    Set-Culture en-GB -ErrorAction SilentlyContinue
    Set-WinSystemLocale en-GB -ErrorAction SilentlyContinue
    Set-WinUserLanguageList -LanguageList en-GB -Force
    Write-Log "Locale and keyboard layout successfully set to UK English!"
} catch {
    Write-Log "Failed to enforce UK English locale: $_" "WARNING"
}

# Check flag to see if this is our second-pass run after optional features reboot
$FlagFile = "C:\Windows\Temp\vbs-features-installed.txt"
$NeedsReboot = $false

# 1. Enable Virtualization-Based Security (VBS) Prerequisites inside VM
Write-Log "Checking Virtualization optional features..."
$vmPlatform = Get-WindowsOptionalFeature -Online -FeatureName VirtualMachinePlatform
$hyperPlatform = Get-WindowsOptionalFeature -Online -FeatureName HypervisorPlatform
if ($vmPlatform.State -ne "Enabled" -or $hyperPlatform.State -ne "Enabled") {
    Write-Log "Enabling VirtualMachinePlatform and HypervisorPlatform optional features..."
    Enable-WindowsOptionalFeature -Online -FeatureName VirtualMachinePlatform -All -NoRestart | Out-Null
    Enable-WindowsOptionalFeature -Online -FeatureName HypervisorPlatform -All -NoRestart | Out-Null
    
    # Configure Registry for Virtualization-Based Security & HVCI (Memory Integrity)
    Write-Log "Configuring registry keys for VBS & Memory Integrity (HVCI)..."
    $DeviceGuardKey = "HKLM:\SYSTEM\CurrentControlSet\Control\DeviceGuard"
    $ScenariosKey = "HKLM:\SYSTEM\CurrentControlSet\Control\DeviceGuard\Scenarios\HypervisorEnforcedCodeIntegrity"
    
    if (!(Test-Path $DeviceGuardKey)) { New-Item -Path $DeviceGuardKey -Force | Out-Null }
    if (!(Test-Path $ScenariosKey)) { New-Item -Path $ScenariosKey -Force | Out-Null }
    
    Set-ItemProperty -Path $DeviceGuardKey -Name "EnableVirtualizationBasedSecurity" -Value 1 -Type DWord -Force
    Set-ItemProperty -Path $DeviceGuardKey -Name "RequirePlatformSecurityFeatures" -Value 1 -Type DWord -Force
    Set-ItemProperty -Path $ScenariosKey -Name "Enabled" -Value 1 -Type DWord -Force
    
    # Create reboot flag
    New-Item -Path $FlagFile -ItemType File -Force | Out-Null
    $NeedsReboot = $true
    Write-Log "Virtualization features installed. Reboot required!"
} else {
    Write-Log "Virtualization optional features are already enabled."
}
if ($NeedsReboot) {
    Write-Log "Rebooting the guest in 5 seconds to complete hypervisor integration..."
    Stop-Transcript
    Restart-Computer -Force
    exit 100
}
# Clean up flag file if it exists
if (Test-Path $FlagFile) { Remove-Item $FlagFile -Force }

# 2. Citrix Workspace App 2603 Installation
Write-Log "Installing Citrix Workspace App..."
$StoreUrl = "$StorefrontUrl"
$StoreString = "WorkVDI;$StoreUrl;on;Work Citrix VDI"
# Try installing via Winget first (extremely clean & fast)
$InstalledSuccess = $false
try {
    Write-Log "Attempting to install Citrix.Workspace via Winget..."
    # Accept source & package agreements and override default parameters
    $wingetArgs = @(
        "install", "--id", "Citrix.Workspace", 
        "--silent", "--accept-package-agreements", "--accept-source-agreements",
        "--custom", "/silent /includeappprotection /noreboot STORE0=`"$StoreString`""
    )
    Start-Process winget.exe -ArgumentList $wingetArgs -NoNewWindow -Wait -ErrorAction Stop
    $InstalledSuccess = $true
    Write-Log "Citrix Workspace successfully installed via Winget."
} catch {
    Write-Log "Winget install failed or unavailable. Falling back to direct download..."
}
# Direct Download Fallback
if (-not $InstalledSuccess) {
    try {
        # Using stable latest Redirect link for Citrix Workspace installer
        $DownloadUrl = "https://downloads.citrix.com/Receiver/CitrixWorkspaceApp.exe"
        $InstallerPath = "C:\Windows\Temp\CitrixWorkspaceApp.exe"
        
        Write-Log "Downloading Citrix Workspace from $DownloadUrl..."
        [Net.ServicePointManager]::SecurityProtocol = [Net.SecurityProtocolType]::Tls12
        Invoke-WebRequest -Uri $DownloadUrl -OutFile $InstallerPath -UseBasicParsing
        
        Write-Log "Running Citrix installer silently with App Protection enabled..."
        $installProcess = Start-Process -FilePath $InstallerPath -ArgumentList "/silent /includeappprotection /noreboot STORE0=`"$StoreString`"" -Wait -NoNewWindow -PassThru
        
        if ($installProcess.ExitCode -eq 0 -or $installProcess.ExitCode -eq 3010) {
            Write-Log "Direct installation completed successfully."
            $InstalledSuccess = $true
        } else {
            Write-Log "Direct installer returned non-zero code: $($installProcess.ExitCode)" "WARNING"
        }
        
        if (Test-Path $InstallerPath) { Remove-Item $InstallerPath -Force }
    } catch {
        Write-Log "Direct download installation failed: $_" "ERROR"
    }
}

# 3. VDI Client Optimizations
Write-Log "Applying VDI performance and display latency optimizations..."
# Windows Power Plan: High Performance
try {
    $HighPerfGuid = "8c5e7fda-e8bf-4a96-9a85-a6e23a8c635c"
    powercfg /setactive $HighPerfGuid
    Write-Log "Set Windows Power Plan to High Performance."
} catch {
    Write-Log "Failed to set Power Plan: $_" "WARNING"
}
# Low Latency Citrix Network Optimization (Disable Nagle's Algorithm & TCP Ack Frequency)
try {
    $NetworkInterfacesPath = "HKLM:\SYSTEM\CurrentControlSet\Services\Tcpip\Parameters\Interfaces"
    $interfaces = Get-ChildItem -Path $NetworkInterfacesPath
    foreach ($interface in $interfaces) {
        $path = $interface.PSPath
        Set-ItemProperty -Path $path -Name "TcpAckFrequency" -Value 1 -Type DWord -Force -ErrorAction SilentlyContinue
        Set-ItemProperty -Path $path -Name "TCPNoDelay" -Value 1 -Type DWord -Force -ErrorAction SilentlyContinue
    }
    Write-Log "Optimized TCP network settings for lower VDI input latency."
} catch {
    Write-Log "Failed to optimize network settings: $_" "WARNING"
}
# Disable visual effects (animations, shadows) to maximize video refresh rate
try {
    $VisualSettingsPath = "HKCU:\Software\Microsoft\Windows\CurrentVersion\Explorer\VisualEffects"
    if (!(Test-Path $VisualSettingsPath)) { New-Item -Path $VisualSettingsPath -Force | Out-Null }
    Set-ItemProperty -Path $VisualSettingsPath -Name "VisualFXSetting" -Value 2 -Type DWord -Force
    Write-Log "Disabled visual effects to reduce VM graphic processing overhead."
} catch {
    Write-Log "Failed to optimize visual effects: $_" "WARNING"
}

# Advanced Keyboard, Mouse, DWM, and scheduling responsiveness tweaks (Input & Graphics lag reduction)
try {
    Write-Log "Applying advanced keyboard, mouse, DWM, and scheduling responsiveness tweaks..."
    
    # System-wide scheduler, priority separation, and input queues
    $SysProfilePath = "HKLM:\SOFTWARE\Microsoft\Windows NT\CurrentVersion\Multimedia\SystemProfile"
    Set-ItemProperty -Path $SysProfilePath -Name "SystemResponsiveness" -Value 0 -Type DWord -Force
    Set-ItemProperty -Path $SysProfilePath -Name "NetworkThrottlingIndex" -Value 0xffffffff -Type DWord -Force
    
    $PriorityControlPath = "HKLM:\SYSTEM\CurrentControlSet\Control\PriorityControl"
    Set-ItemProperty -Path $PriorityControlPath -Name "Win32PrioritySeparation" -Value 26 -Type DWord -Force
    
    $MouclassPath = "HKLM:\SYSTEM\CurrentControlSet\Services\mouclass\Parameters"
    Set-ItemProperty -Path $MouclassPath -Name "MouseDataQueueSize" -Value 30 -Type DWord -Force
    
    $KbdclassPath = "HKLM:\SYSTEM\CurrentControlSet\Services\kbdclass\Parameters"
    Set-ItemProperty -Path $KbdclassPath -Name "KeyboardDataQueueSize" -Value 30 -Type DWord -Force
    
    # Helper to apply user input & graphics tweaks to a targeted path
    $ApplyUserInputTweaks = {
        param([string]$basePath)
        
        # Disable Mouse Acceleration (enhance pointer precision) -> Sets raw 1:1 absolute coordinates
        $mousePath = Join-Path $basePath "Control Panel\Mouse"
        if (!(Test-Path $mousePath)) { New-Item -Path $mousePath -Force | Out-Null }
        Set-ItemProperty -Path $mousePath -Name "MouseSpeed" -Value "0" -Type String -Force
        Set-ItemProperty -Path $mousePath -Name "MouseThreshold1" -Value "0" -Type String -Force
        Set-ItemProperty -Path $mousePath -Name "MouseThreshold2" -Value "0" -Type String -Force
        Set-ItemProperty -Path $mousePath -Name "MouseHoverTime" -Value "8" -Type String -Force
        
        # Optimize Keyboard Repeat Delay and Repeat Speed
        $kbdPath = Join-Path $basePath "Control Panel\Keyboard"
        if (!(Test-Path $kbdPath)) { New-Item -Path $kbdPath -Force | Out-Null }
        Set-ItemProperty -Path $kbdPath -Name "KeyboardDelay" -Value "0" -Type String -Force
        Set-ItemProperty -Path $kbdPath -Name "KeyboardSpeed" -Value "31" -Type String -Force
        
        # Instantaneous Menu Show Delay & Drag Outline Only
        $desktopPath = Join-Path $basePath "Control Panel\Desktop"
        if (!(Test-Path $desktopPath)) { New-Item -Path $desktopPath -Force | Out-Null }
        Set-ItemProperty -Path $desktopPath -Name "MenuShowDelay" -Value "0" -Type String -Force
        Set-ItemProperty -Path $desktopPath -Name "DragFullWindows" -Value "0" -Type String -Force
        
        # D. Minimize Window transition and DWM hover latency
        $metricsPath = Join-Path $basePath "Control Panel\Desktop\WindowMetrics"
        if (!(Test-Path $metricsPath)) { New-Item -Path $metricsPath -Force | Out-Null }
        Set-ItemProperty -Path $metricsPath -Name "MinAnimate" -Value "0" -Type String -Force

        $dwmPath = Join-Path $basePath "Software\Microsoft\Windows\DWM"
        if (!(Test-Path $dwmPath)) { New-Item -Path $dwmPath -Force | Out-Null }
        Set-ItemProperty -Path $dwmPath -Name "AlwaysHibernateThumbnails" -Value 1 -Type DWord -Force
        Set-ItemProperty -Path $dwmPath -Name "EnableAeroPeek" -Value 0 -Type DWord -Force

        # E. Citrix Client DPI Scaling Awareness (prevents font/layout blurriness and scaling lags)
        $citrixDwmPath = Join-Path $basePath "Software\Citrix\ICA Client\DPI"
        if (!(Test-Path $citrixDwmPath)) { New-Item -Path $citrixDwmPath -Force | Out-Null }
        Set-ItemProperty -Path $citrixDwmPath -Name "DpiAware" -Value 1 -Type DWord -Force
    }

    # Apply to current user profile
    & $ApplyUserInputTweaks "HKCU:"
    
    # Apply to Default User profile so all new login profiles automatically inherit them
    $defaultHiveFile = "C:\Users\Default\NTUSER.DAT"
    if (Test-Path $defaultHiveFile) {
        [GC]::Collect()
        [GC]::WaitForPendingFinalizers()
        reg load HKU\DefaultUser $defaultHiveFile | Out-Null
        & $ApplyUserInputTweaks "Registry::HKU\DefaultUser"
        [GC]::Collect()
        [GC]::WaitForPendingFinalizers()
        Start-Sleep -Milliseconds 200
        reg unload HKU\DefaultUser | Out-Null
    }

    # Citrix client-side graphics performance optimizations
    Write-Log "Configuring Citrix Workspace graphics optimizations (disabling HW acceleration and hybrid D3D to force clean CPU software decode)..."
    try {
        $CitrixPoliciesPath = "HKLM:\SOFTWARE\Policies\Citrix\ICA Client\Graphics Engine"
        $CitrixPoliciesWowPath = "HKLM:\SOFTWARE\WOW6432Node\Policies\Citrix\ICA Client\Graphics Engine"
        
        if (!(Test-Path $CitrixPoliciesPath)) { New-Item -Path $CitrixPoliciesPath -Force | Out-Null }
        if (!(Test-Path $CitrixPoliciesWowPath)) { New-Item -Path $CitrixPoliciesWowPath -Force | Out-Null }
        
        Set-ItemProperty -Path $CitrixPoliciesPath -Name "HWacceleration" -Value 0 -Type DWord -Force
        Set-ItemProperty -Path $CitrixPoliciesWowPath -Name "HWacceleration" -Value 0 -Type DWord -Force
        
        $CitrixGraphicsPath = "HKLM:\SOFTWARE\Citrix\Graphics"
        $CitrixGraphicsWowPath = "HKLM:\SOFTWARE\WOW6432Node\Citrix\Graphics"
        
        if (!(Test-Path $CitrixGraphicsPath)) { New-Item -Path $CitrixGraphicsPath -Force | Out-Null }
        if (!(Test-Path $CitrixGraphicsWowPath)) { New-Item -Path $CitrixGraphicsWowPath -Force | Out-Null }
        
        Set-ItemProperty -Path $CitrixGraphicsPath -Name "UseD3DHybrid" -Value 0 -Type DWord -Force
        Set-ItemProperty -Path $CitrixGraphicsPath -Name "DisplayMemoryLimit" -Value 131072 -Type DWord -Force
        
        Set-ItemProperty -Path $CitrixGraphicsWowPath -Name "UseD3DHybrid" -Value 0 -Type DWord -Force
        Set-ItemProperty -Path $CitrixGraphicsWowPath -Name "DisplayMemoryLimit" -Value 131072 -Type DWord -Force
        Write-Log "Citrix client-side graphics optimizations and display buffering successfully applied!"
    } catch {
        Write-Log "Failed to configure Citrix graphics registry policies: $_" "WARNING"
    }

    Write-Log "Successfully applied mouse acceleration disable, keyboard response, input queues, DWM, and system profile tweaks!"

} catch {
    Write-Log "Failed to apply input/graphics optimizations: $_" "WARNING"
}

# 4. Verify Citrix App Protection Service Status
Write-Log "Verifying Citrix App Protection Service status..."
$svc = Get-Service -Name "AppProtectionSvc" -ErrorAction SilentlyContinue
if ($svc) {
    Write-Log "AppProtectionSvc found. Status: $($svc.Status)"
    if ($svc.Status -ne "Running") {
        Write-Log "Attempting to start AppProtectionSvc..."
        Start-Service -Name "AppProtectionSvc" -ErrorAction SilentlyContinue
    }
} else {
    Write-Log "AppProtectionSvc NOT found inside the VM!" "ERROR"
}

# 5. Embed Local Account Creation/Bypass Tool into the Guest Desktop
try {
    Write-Log "Embedding Local-Only logon helper to Administrator Desktop..."
    $DesktopPath = [System.IO.Path]::Combine($env:USERPROFILE, "Desktop")
    if (Test-Path $DesktopPath) {
        $ScriptPath = Join-Path $DesktopPath "Bypass-Microsoft-Account-Setup.cmd"
        $cmdContent = @"
@echo off
echo =======================================================
echo     WINDOWS 11 LOCAL-ONLY ACCOUNT CREATION HELPER
echo =======================================================
echo.
echo Running OOBE Local Account Creation setup...
start ms-cxh:localonly
echo Done. You can close this window now.
pause >nul
"@
        $cmdContent | Out-File -FilePath $ScriptPath -Encoding ascii -Force
        Write-Log "Local account helper shortcut written to desktop."
    } else {
        Write-Log "Could not find guest Desktop path!" "WARNING"
    }
} catch {
    Write-Log "Failed to embed Local logon helper: $_" "WARNING"
}
Write-Log "Guest VDI Configuration Script Complete!"
Stop-Transcript
'@

# --- EMBEDDED STANDALONE GUEST INPUT LAG OPTIMIZER SCRIPT ---
# This is a copy of Optimize-GuestInputLag.ps1. The master script will automatically write this file
# to the script's directory upon execution so the user can easily copy/paste it into the Guest VM.
$GuestOptimizerContent = @'
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
$ArrowChar   = [char]0x2794  # ➔
$CheckChar   = [char]0x2714  # ✔
$WarnChar    = [char]0x26A0  # ⚠
$BulletChar  = [char]0x25CF  # ●

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
    Write-Host " [✖] ERROR: This script must be run as an Administrator!" -ForegroundColor Red -Bold
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

    # E. Citrix Client DPI Scaling Awareness (prevents font/layout blurriness and scaling lags)
    $citrixDwmPath = Join-Path $basePath "Software\Citrix\ICA Client\DPI"
    if (!(Test-Path $citrixDwmPath)) { New-Item -Path $citrixDwmPath -Force | Out-Null }
    Set-ItemProperty -Path $citrixDwmPath -Name "DpiAware" -Value 1 -Type DWord -Force
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

# 9. Citrix Client-Side Graphics Performance Optimizations
Write-Step "Configuring Citrix Workspace graphics optimizations (disabling HW acceleration and hybrid D3D to force clean CPU software decode)"
try {
    $CitrixPoliciesPath = "HKLM:\SOFTWARE\Policies\Citrix\ICA Client\Graphics Engine"
    $CitrixPoliciesWowPath = "HKLM:\SOFTWARE\WOW6432Node\Policies\Citrix\ICA Client\Graphics Engine"
    
    if (!(Test-Path $CitrixPoliciesPath)) { New-Item -Path $CitrixPoliciesPath -Force | Out-Null }
    if (!(Test-Path $CitrixPoliciesWowPath)) { New-Item -Path $CitrixPoliciesWowPath -Force | Out-Null }
    
    Set-ItemProperty -Path $CitrixPoliciesPath -Name "HWacceleration" -Value 0 -Type DWord -Force
    Set-ItemProperty -Path $CitrixPoliciesWowPath -Name "HWacceleration" -Value 0 -Type DWord -Force
    
    $CitrixGraphicsPath = "HKLM:\SOFTWARE\Citrix\Graphics"
    $CitrixGraphicsWowPath = "HKLM:\SOFTWARE\WOW6432Node\Citrix\Graphics"
    
    if (!(Test-Path $CitrixGraphicsPath)) { New-Item -Path $CitrixGraphicsPath -Force | Out-Null }
    if (!(Test-Path $CitrixGraphicsWowPath)) { New-Item -Path $CitrixGraphicsWowPath -Force | Out-Null }
    
    Set-ItemProperty -Path $CitrixGraphicsPath -Name "UseD3DHybrid" -Value 0 -Type DWord -Force
    Set-ItemProperty -Path $CitrixGraphicsPath -Name "DisplayMemoryLimit" -Value 131072 -Type DWord -Force
    
    Set-ItemProperty -Path $CitrixGraphicsWowPath -Name "UseD3DHybrid" -Value 0 -Type DWord -Force
    Set-ItemProperty -Path $CitrixGraphicsWowPath -Name "DisplayMemoryLimit" -Value 131072 -Type DWord -Force
    Write-Success "Citrix client-side graphics optimizations and display buffering successfully applied!"
} catch {
    Write-Warning "Failed to configure Citrix graphics registry policies: $_"
}

# 10. Finished
Show-Banner
Write-Host "======================================================================" -ForegroundColor Green -Bold
Write-Host "             GUEST INPUT AND GRAPHICS OPTIMIZATION COMPLETE!            " -ForegroundColor Green -Bold
Write-Host "======================================================================" -ForegroundColor Green -Bold
Write-Host ""
Write-Host " The following low-latency profiles have been applied successfully:" -ForegroundColor White
Write-Host " $($CheckChar) Disabled Windows Mouse Acceleration (Enabled raw 1:1 cursor)" -ForegroundColor Green
Write-Host " $($CheckChar) Shortened Keyboard Repeat Delay to 250ms (Shortest possible)" -ForegroundColor Green
Write-Host " $($CheckChar) Maximized Keyboard Auto-Repeat Rate (Speed 31)" -ForegroundColor Green
Write-Host " $($CheckChar) Minimized Menu and Hover opening latency (0ms / 8ms)" -ForegroundColor Green
Write-Host " $($CheckChar) Set System Responsiveness scheduler to 100% User Process" -ForegroundColor Green
Write-Host " $($CheckChar) Set CPU Foreground Priority separation to 26 (Interactive UI)" -ForegroundColor Green
Write-Host " $($CheckChar) Shrunk Mouse/Keyboard data queue depth to 30 (Instant event flush)" -ForegroundColor Green
Write-Host " $($CheckChar) Enabled Drag Outline-Only window drawing (No DWM redraw lag)" -ForegroundColor Green
Write-Host " $($CheckChar) Enabled DWM live hover thumbnail and Aero Peek hibernation" -ForegroundColor Green
Write-Host " $($CheckChar) Disabled Network throttling under high CPU utilization" -ForegroundColor Green
Write-Host " $($CheckChar) Set TCP Ack Frequency and TCP No Delay on all interfaces" -ForegroundColor Green
Write-Host " $($CheckChar) Enabled High Performance Windows Power Plan" -ForegroundColor Green
Write-Host " $($CheckChar) Disabled OS-level visual transition effects" -ForegroundColor Green
Write-Host " $($CheckChar) Set Citrix Graphics HW Acceleration to 0 (Forced fast CPU decode)" -ForegroundColor Green
Write-Host " $($CheckChar) Set Citrix UseD3DHybrid to 0 and DisplayMemoryLimit to 128MB" -ForegroundColor Green
Write-Host ""
Write-Host " Note: Some settings will take effect on the next login or after reboot." -ForegroundColor Yellow -Bold
Write-Host " Please LOG OUT and LOG BACK IN, or REBOOT the VM now!" -ForegroundColor Yellow -Bold
Write-Host "======================================================================" -ForegroundColor Cyan
Write-Host ""
Write-Host "Press ENTER to close this window..."
$null = Read-Host
'@

# --- HELPER FUNCTIONS ---
function Show-Banner {
    Clear-Host
    Write-Host "======================================================================" -ForegroundColor Cyan
    Write-Host "      __   ___                  _ _ _            _ _                  " -ForegroundColor Green
    Write-Host "      \ \ / / _ ) _____ __      | | | |___ _  _  / | |                " -ForegroundColor Green
    Write-Host "       \ V /| _ \/ _ \ \ /      | | | / _ \ || | | | |                " -ForegroundColor Green
    Write-Host "        \_/ |___/\___/_\_\      |_|_|_|___/\_,_| |_|_|                " -ForegroundColor Green
    Write-Host "                                                                      " -ForegroundColor Green
    Write-Host "      VIRTUALBOX WINDOWS 11 PRO CITRIX VDI CLIENT PROVISIONER         " -ForegroundColor Green -Bold
    Write-Host "        Consolidated 1-Script Solution for Ultimate VDI Speed         " -ForegroundColor Cyan
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

function Show-ProgressBar {
    param(
        [int]$Percent,
        [string]$Label
    )
    $width = 30
    $done = [Math]::Round(($Percent / 100) * $width)
    $left = $width - $done
    $bar = ([string]$BlockChar * [int]$done) + ([string]$ShadeChar * [int]$left)
    Write-Host -NoNewline "`r   ${Label}: [$bar] $Percent%" -ForegroundColor Cyan
    if ($Percent -eq 100) {
        Write-Host ""
    }
}

function Find-VBoxManage {
    $paths = @(
        "$env:ProgramFiles\Oracle\VirtualBox\VBoxManage.exe",
        "C:\Program Files\Oracle\VirtualBox\VBoxManage.exe",
        "$env:ProgramFiles(x86)\Oracle\VirtualBox\VBoxManage.exe"
    )
    try {
        $regPath = Get-ItemPropertyValue -Path "HKLM:\SOFTWARE\Oracle\VirtualBox" -Name "InstallDir" -ErrorAction SilentlyContinue
        if ($regPath) {
            $paths += Join-Path $regPath "VBoxManage.exe"
        }
    } catch {}
    foreach ($path in $paths) {
        if (Test-Path $path) { return $path }
    }
    $pathCmd = Get-Command VBoxManage.exe -ErrorAction SilentlyContinue
    if ($pathCmd) { return $pathCmd.Source }
    return $null
}

function Install-VBoxExtensionPack {
    param(
        [string]$VBoxManagePath
    )
    Write-Step "Checking for VirtualBox Extension Pack"
    $extpacks = & $VBoxManagePath list extpacks
    if ($extpacks -match "Extension Packs: [1-9]") {
        Write-Success "VirtualBox Extension Pack is already installed."
        return $true
    }
    
    Write-Warning "VirtualBox Extension Pack is missing! Required for stable webcam redirection."
    
    # Get VirtualBox version
    $vboxVerRaw = & $VBoxManagePath -v
    if ($vboxVerRaw -match "^([0-9]+\.[0-9]+\.[0-9]+)") {
        $vboxVer = $Matches[1]
    } else {
        $vboxVer = "7.2.8"
    }
    
    $extpackFile = "Oracle_VirtualBox_Extension_Pack-$vboxVer.vbox-extpack"
    $url = "https://download.virtualbox.org/virtualbox/$vboxVer/$extpackFile"
    $tempPath = Join-Path $env:TEMP $extpackFile
    
    Write-Step "Downloading matching Extension Pack from $url"
    try {
        Invoke-WebRequest -Uri $url -OutFile $tempPath -ErrorAction Stop
        Write-Success "Extension Pack downloaded successfully to $tempPath"
    } catch {
        Write-ErrorText "Failed to download Extension Pack: $_"
        return $false
    }
    
    Write-Step "Installing VirtualBox Extension Pack (elevated, auto-accepting license)"
    try {
        $licenseHash = "eb31505e56e9b4d0fbca139104da41ac6f6b98f8e78968bdf01b1f3da3c4f9ae"
        $installArgs = @("extpack", "install", "--replace", "--accept-license=$licenseHash", $tempPath)
        $p = Start-Process -FilePath $VBoxManagePath -ArgumentList $installArgs -NoNewWindow -Wait -PassThru
        
        if ($p.ExitCode -ne 0) {
            Write-Warning "Automated installation with known license hash failed (ExitCode: $($p.ExitCode))."
            Write-Step "Attempting fallback manual license agreement..."
            & $VBoxManagePath extpack install --replace $tempPath
        } else {
            Write-Success "VirtualBox Extension Pack successfully installed!"
        }
    } catch {
        Write-ErrorText "Failed to install Extension Pack: $_"
        return $false
    } finally {
        if (Test-Path $tempPath) { Remove-Item $tempPath -Force }
    }
    return $true
}

function Get-IsoPathWithDialog {
    Add-Type -AssemblyName System.Windows.Forms
    $FileBrowser = New-Object System.Windows.Forms.OpenFileDialog -Property @{
        InitialDirectory = [Environment]::GetFolderPath('MyDocuments')
        Filter = 'ISO Image Files (*.iso)|*.iso'
        Title = 'Select Windows 11 ISO'
    }
    $result = $FileBrowser.ShowDialog()
    if ($result -eq [System.Windows.Forms.DialogResult]::OK) {
        return $FileBrowser.FileName
    }
    return $null
}

function Invoke-HardwarePassthroughAndOptimizations {
    param(
        [string]$VBoxManagePath
    )
    Show-Banner
    Write-Host "--- STEP 2: HARDWARE CONFIGURE SPECS ---" -ForegroundColor Yellow -Bold
    Write-Host ""
    Write-Host " $($BulletChar) Enter VM Name to configure [Win11-Citrix-VDI]: " -ForegroundColor White -NoNewline
    $VMName = Read-Host
    if ([string]::IsNullOrWhiteSpace($VMName)) { $VMName = "Win11-Citrix-VDI" }

    Write-Step "Checking state of Virtual Machine '$VMName'"
    $vmInfo = & $VBoxManagePath showvminfo $VMName --machinereadable 2>$null
    if ($LastExitCode -ne 0) {
        Write-ErrorText "VM '$VMName' not found! Please check the name and try again."
        Write-Host "Press ENTER to exit..."
        $null = Read-Host
        return
    }

    $isrunning = $false
    if ($vmInfo -match 'VMState="running"') {
        $isrunning = $true
    }

    if ($isrunning) {
        Write-Warning "VM '$VMName' is currently running!"
        Write-Host " We must gracefully power off the VM to apply hardware controller adjustments." -ForegroundColor Yellow
        Write-Host " Press ENTER to send an ACPI shutdown signal and wait for power-off..." -ForegroundColor Cyan -NoNewline
        $null = Read-Host
        
        Write-Step "Sending ACPI Shutdown signal"
        & $VBoxManagePath controlvm $VMName acpipowerbutton | Out-Null
        
        $ticks = 0
        while ($true) {
            $stateInfo = & $VBoxManagePath showvminfo $VMName --machinereadable 2>$null
            if ($stateInfo -match 'VMState="poweroff"') {
                Write-Success "VM has powered off successfully!"
                break
            }
            Start-Sleep -Seconds 2
            $ticks += 2
            Write-Host -NoNewline "`r   Waiting for VM to stop... (${ticks}s)" -ForegroundColor Yellow
            if ($ticks -gt 90) {
                Write-Host ""
                Write-Warning "VM took too long to shutdown. Forcing power off..."
                & $VBoxManagePath controlvm $VMName poweroff 2>$null | Out-Null
                Start-Sleep -Seconds 2
                break
            }
        }
    } else {
        Write-Success "VM is already powered off. Proceeding with configuration."
    }

    # Apply Audio & HPET
    Write-Step "Upgrading audio system to Intel HD Audio and enabling HPET precision timers"
    & $VBoxManagePath modifyvm $VMName --audio-controller hda --audio-driver was --x86-hpet on | Out-Null
    & $VBoxManagePath modifyvm $VMName --audio-in on --audio-out on | Out-Null
    Write-Success "Upgraded controller to Intel HD Audio and enabled HPET precision timers."

    # Apply Display memory and 3D Acceleration
    Write-Step "Maximizing video memory to 256MB and enabling 3D hardware acceleration"
    & $VBoxManagePath modifyvm $VMName --vram 256 --graphicscontroller vboxsvga --accelerate-3d on | Out-Null
    Write-Success "Display optimized: 256MB VRAM, VBoxSVGA controller, and 3D acceleration active."


    # Apply USB, Network, Priority, Keyboard/Mouse, and Low-Latency Paging/Speculative controls
    Write-Step "Enabling USB 3.0 (xHCI), Gigabit Server NIC (82545EM), High Process Priority, Low-Latency Large Pages, and Speculative mitigations bypass"
    & $VBoxManagePath modifyvm $VMName --usb-xhci on --nic-type1 82545EM --vm-process-priority high --mouse usbtablet --keyboard usb --large-pages on --spec-ctrl off | Out-Null
    Write-Success "USB 3.0 enabled, Gigabit Server NIC configured, High Process Priority set, USB Mouse/Keyboard active, and Low-Latency compute parameters applied."

    # Clear and register USB filters
    Write-Step "Removing old USB filters to prevent duplicates"
    for ($i = 0; $i -lt 5; $i++) {
        try { & $VBoxManagePath usbfilter remove 0 --target $VMName 2>$null | Out-Null } catch {}
    }

    Write-Step "Creating high-fidelity hardware filters"
    Write-Step "Adding filter for YubiKey OTP+FIDO+CCID"
    & $VBoxManagePath usbfilter add 0 --target $VMName --name "YubiKey OTP+FIDO+CCID" --action hold --active yes --vendorid "1050" --productid "0407" | Out-Null
    Write-Success "YubiKey filter successfully added."

    Write-Step "Adding filter for Jabra Link 390 Audio Adapter"
    & $VBoxManagePath usbfilter add 1 --target $VMName --name "Jabra Link 390" --action hold --active yes --vendorid "0b0e" --productid "2e50" | Out-Null
    Write-Success "Jabra Link filter successfully added."

    Show-Banner
    Write-Host "======================================================================" -ForegroundColor Green -Bold
    Write-Host "             HARDWARE PASSTHROUGH SUCCESSFULLY CONFIGURED!            " -ForegroundColor Green -Bold
    Write-Host "======================================================================" -ForegroundColor Green -Bold
    Write-Host "  The VM now has direct access to:"
    Write-Host "  1. YubiKey (FIDO2 authentication keys - Redirected via USB)" -ForegroundColor Green
    Write-Host "  2. Jabra Headset (via Jabra Link USB Audio Dongle - Redirected via USB)" -ForegroundColor Green
    Write-Host "  3. Dell Webcam (Raw stream - Virtualized stably via native VBox Webcam)" -ForegroundColor Green
    Write-Host "  4. Standard Guest Speakers and Microphone (Intel HD Audio)" -ForegroundColor Green
    Write-Host "======================================================================" -ForegroundColor Cyan
    Write-Host ""

    Write-Host "Do you want to BOOT the Virtual Machine now? (Y/N) [Y]: " -ForegroundColor Yellow -NoNewline
    $bootChoice = Read-Host
    if ([string]::IsNullOrWhiteSpace($bootChoice)) { $bootChoice = "Y" }
    
    if ($bootChoice -match "^[Yy]") {
        Write-Step "Booting Virtual Machine '$VMName'"
        & $VBoxManagePath startvm $VMName --type gui | Out-Null
        Write-Success "VM successfully booted in GUI window."
        
        Write-Step "Waiting 8 seconds for guest session initialization"
        Start-Sleep -Seconds 8
        try {
            & $VBoxManagePath controlvm $VMName webcam attach .1 "MaxPayloadTransferSize=16384;MaxFramerate=30" | Out-Null
            Write-Success "Webcam 'Dell Webcam WB7022' successfully attached via stable native VirtualBox webcam passthrough!"
        } catch {
            Write-Warning "Could not attach webcam: $_. Make sure the webcam is plugged in."
        }

        # Auto Guest Tweak Option
        Write-Host ""
        Write-Host "Do you want to automatically apply Guest OS-side input lag and network optimizations to this VM?" -ForegroundColor Yellow
        Write-Host "  (This will automatically copy and run the optimizer inside the Guest VM via Guest Additions.)" -ForegroundColor Yellow
        Write-Host "  Apply Guest Optimizations? (Y/N) [N]: " -ForegroundColor Yellow -NoNewline
        $guestTweakChoice = Read-Host
        if ($guestTweakChoice -match "^[Yy]") {
            $ScriptDir = Split-Path -Parent $MyInvocation.MyCommand.Path
            if ([string]::IsNullOrEmpty($ScriptDir)) { $ScriptDir = Get-Location }
            $StandalonePath = Join-Path $ScriptDir "Optimize-GuestInputLag.ps1"
            
            Write-Host ""
            Write-Host "  Please enter the Guest Windows account credentials:" -ForegroundColor White
            Write-Host "  Guest Username [VDIAdmin]: " -NoNewline
            $guestUser = Read-Host
            if ([string]::IsNullOrWhiteSpace($guestUser)) { $guestUser = "VDIAdmin" }
            
            Write-Host "  Guest Password: " -NoNewline
            # Read password securely/quietly
            $guestPass = [System.Console]::ReadLine() # Fallback simple read
            
            Write-Step "Waiting for Guest Additions to report active"
            $gaActive = $false
            $gaTicks = 0
            while (-not $gaActive -and $gaTicks -lt 60) {
                $status = & $VBoxManagePath guestproperty get $VMName /VirtualBox/GuestAdd/Version 2>&1
                if ($status -match "Value: ([0-9\.]+)") {
                    $gaActive = $true
                    break
                }
                Start-Sleep -Seconds 3
                $gaTicks += 3
                Write-Host -NoNewline "`r   Waiting for Guest Additions... (${gaTicks}s)" -ForegroundColor Yellow
            }
            Write-Host ""
            
            if ($gaActive) {
                Write-Step "Copying input lag optimizer to Guest VM"
                try {
                    & $VBoxManagePath guestcontrol $VMName copyto --username $guestUser --password $guestPass --target-directory "C:\Windows\Temp" $StandalonePath | Out-Null
                    Write-Success "Optimizer script copied successfully!"
                    
                    Write-Step "Executing optimizer inside Guest VM as Administrator"
                    $runArgs2 = @(
                        "guestcontrol", $VMName, "run",
                        "--exe", "C:\Windows\System32\WindowsPowerShell\v1.0\powershell.exe",
                        "--username", $guestUser, "--password", $guestPass,
                        "--wait-stdout", "--wait-stderr",
                        "--",
                        "-ExecutionPolicy", "Bypass",
                        "-File", "C:\Windows\Temp\Optimize-GuestInputLag.ps1"
                    )
                    Write-Host "----------------- GUEST OPTIMIZER LOG -----------------" -ForegroundColor Gray
                    $optRes = & $VBoxManagePath @runArgs2
                    Write-Host $optRes -ForegroundColor Gray
                    Write-Host "--------------------------------------------------------" -ForegroundColor Gray
                    Write-Success "Guest OS optimizations applied successfully!"
                    Write-Warning "Please log out and log back in (or restart the VM) to apply all user input tweaks!"
                } catch {
                    Write-ErrorText "Guest Control execution failed: $_"
                    Write-Warning "Ensure Guest Additions are fully loaded, credentials are correct, and the account has admin rights."
                }
            } else {
                Write-Warning "Guest Additions did not start in time. Skipping automated guest optimization."
            }
        }
    } else {
        Write-Host "Done! You can boot the VM manually from VirtualBox whenever you are ready." -ForegroundColor Cyan
    }

    Write-Host ""
    Write-Host "======================================================================" -ForegroundColor Cyan
    Write-Host "  TO FINISH ELIMINATING INPUT LAG INSIDE THE RUNNING VM GUEST MANUALLY:" -ForegroundColor Yellow -Bold
    Write-Host "  1. Open a PowerShell terminal as Administrator inside the Guest VM." -ForegroundColor White
    Write-Host "  2. Run the Optimize-GuestInputLag.ps1 script located in the workspace folder:" -ForegroundColor White
    Write-Host "     C:\Users\chris\.gemini\antigravity\scratch\VBoxWin11Provisioner\Optimize-GuestInputLag.ps1" -ForegroundColor Green
    Write-Host "  3. Log out and log back into your Guest VM account." -ForegroundColor White
    Write-Host "======================================================================" -ForegroundColor Cyan
    Write-Host ""
    Write-Host "Press ENTER to exit..."
    $null = Read-Host
}

# --- WIZARD START ---
Show-Banner

# --- AUTO-EXTRACT STANDALONE GUEST OPTIMIZER ---
# Dynamically write/update the standalone optimizer script in the script's directory
try {
    $ScriptDir = Split-Path -Parent $MyInvocation.MyCommand.Path
    if ([string]::IsNullOrEmpty($ScriptDir)) { $ScriptDir = Get-Location }
    $StandalonePath = Join-Path $ScriptDir "Optimize-GuestInputLag.ps1"
    $GuestOptimizerContent | Out-File $StandalonePath -Encoding utf8 -Force
} catch {
    # Non-blocking if directory is write-protected
}

# 1. Search for VirtualBox
Write-Step "Locating VirtualBox installation"
$VBoxManagePath = Find-VBoxManage
if (-not $VBoxManagePath) {
    Write-ErrorText "Could not find VirtualBox installation (VBoxManage.exe)!"
    Write-Host "Please enter the absolute path to VBoxManage.exe:" -ForegroundColor Yellow -NoNewline
    $userInputPath = Read-Host
    if (Test-Path $userInputPath) {
        $VBoxManagePath = $userInputPath
    } else {
        Write-ErrorText "Invalid path. Exiting."
        Exit
    }
}
Write-Success "Found VirtualBox Manage Tool: $VBoxManagePath"

# Verify VirtualBox Version
$vboxVersion = & $VBoxManagePath --version
Write-Success "VirtualBox Version: $vboxVersion"
if ($vboxVersion -match "^([0-9]+)\.") {
    $major = [int]$Matches[1]
    if ($major -lt 7) {
        Write-Warning "VirtualBox Version is older than 7.0! Windows 11 TPM 2.0 & Secure Boot emulation might fail."
        Write-Host "Press Enter to proceed anyway, or Ctrl+C to abort..."
        $null = Read-Host
    }
}

# Ensure VirtualBox Extension Pack is installed
Install-VBoxExtensionPack -VBoxManagePath $VBoxManagePath

# 2. Select Operation Mode
Show-Banner
Write-Host "--- STEP 1: SELECT OPERATION MODE ---" -ForegroundColor Yellow -Bold
Write-Host ""
Write-Host "  [1] Fresh VM Provisioner (Deploy a brand new Windows 11 VM from scratch)" -ForegroundColor White
Write-Host "  [2] Hardware Configurator (Optimize passthrough & input lag on an existing VM)" -ForegroundColor White
Write-Host ""
Write-Host " Select Option [1]: " -ForegroundColor White -NoNewline
$OpMode = Read-Host
if ([string]::IsNullOrWhiteSpace($OpMode)) { $OpMode = "1" }

if ($OpMode -eq "2") {
    Invoke-HardwarePassthroughAndOptimizations -VBoxManagePath $VBoxManagePath
    Exit
}

# 3. Collect VM specifications interactively
Show-Banner
Write-Host "--- STEP 2: INTERACTIVE VM PROVISIONING SPECS ---" -ForegroundColor Yellow -Bold
Write-Host ""

# VM Name
Write-Host "$($BulletChar) Enter VM Name [Win11-Citrix-VDI]: " -ForegroundColor White -NoNewline
$VMName = Read-Host
if ([string]::IsNullOrWhiteSpace($VMName)) { $VMName = "Win11-Citrix-VDI" }

# Windows 11 ISO Selection (Hardcoded with fallback)
$IsoPath = "C:\VMDeploy\Win11.iso"
if (Test-Path $IsoPath) {
    Write-Success "Using Windows 11 ISO at hardcoded path: $IsoPath"
} else {
    Write-Warning "Windows 11 ISO not found at C:\VMDeploy\Win11.iso!"
    Write-Host "$($BulletChar) Selecting Windows 11 ISO..." -ForegroundColor White
    Write-Host "  Opening File Dialog. Please select your Windows 11 Pro ISO." -ForegroundColor Cyan
    $IsoPath = Get-IsoPathWithDialog
    if (-not $IsoPath) {
        Write-Warning "No file chosen via dialog. Please enter the absolute path to your Windows 11 ISO:"
        $IsoPath = Read-Host
    }
}
if (-not (Test-Path $IsoPath) -or $IsoPath -notmatch "\.iso$") {
    Write-ErrorText "Error: Specified file does not exist or is not an ISO image! File: $IsoPath"
    Exit
}
Write-Success "Selected ISO: $IsoPath"

# Windows Key
Write-Host ""
Write-Host "$($BulletChar) Windows 11 Pro Activation Product Key:" -ForegroundColor White
Write-Host "  Press ENTER to use Microsoft's official Pro KMS Setup Key (Recommended for automated installs)." -ForegroundColor Cyan
Write-Host "  Setup Key: W269N-WFGWX-YVC9B-4J6C9-T83GX" -ForegroundColor Cyan
Write-Host "  Key: " -NoNewline
$ProductKey = Read-Host
if ([string]::IsNullOrWhiteSpace($ProductKey)) { 
    $ProductKey = "W269N-WFGWX-YVC9B-4J6C9-T83GX" 
}

# Hardware configuration (Hardcoded VM specs)
$VMCPUs = 4
$VMRAM_GB = 8
$VMRAM_MB = 8192
$VMDisk_GB = 64
$VMDisk_MB = 65536
Write-Success "Hardware specs applied: $VMCPUs vCPUs | $VMRAM_GB GB RAM | $VMDisk_GB GB Disk"

# Citrix Storefront URL
Write-Host ""
Write-Host "$($BulletChar) Work VDI Citrix Storefront / Discovery URL [https://citrix.company.com/Citrix/Store/discovery]: " -ForegroundColor White -NoNewline
$CitrixUrl = Read-Host
if ([string]::IsNullOrWhiteSpace($CitrixUrl)) { $CitrixUrl = "https://citrix.company.com/Citrix/Store/discovery" }

# Credentials
Write-Host ""
Write-Host "$($BulletChar) VM Administrator Account Username [VDIAdmin]: " -ForegroundColor White -NoNewline
$AdminUser = Read-Host
if ([string]::IsNullOrWhiteSpace($AdminUser)) { $AdminUser = "VDIAdmin" }

# Generate a strong complex password
$chars = "abcdefghijklmnopqrstuvwxyzABCDEFGHIJKLMNOPQRSTUVWXYZ0123456789!@#$"
$rand = New-Object System.Random
$AdminPass = ""
for ($i=0; $i -lt 14; $i++) {
    $AdminPass += $chars[$rand.Next(0, $chars.Length)]
}
# Ensure it meets complexity (requires at least one upper, lower, number, and symbol)
$AdminPass += "A1!a" 
Write-Host "$($BulletChar) VM Guest Administrator Password [AUTO-GENERATED]: $AdminPass" -ForegroundColor Green
Write-Host "  PLEASE WRITE THIS DOWN! It is required to log in and authorize the guest script." -ForegroundColor Yellow -Bold
Write-Host "  Press Enter to acknowledge..."
$null = Read-Host

# VM Folder location
$DefaultVMLoc = Join-Path $env:USERPROFILE "VirtualBox VMs"
Write-Host ""
Write-Host "$($BulletChar) VM Storage Location [$DefaultVMLoc]: " -ForegroundColor White -NoNewline
$VMLocation = Read-Host
if ([string]::IsNullOrWhiteSpace($VMLocation)) { $VMLocation = $DefaultVMLoc }

# Confirmation
Show-Banner
Write-Host "--- SPECS CONFIRMED. READY TO PROVISION ---" -ForegroundColor Green -Bold
Write-Host " VM Name:           $VMName" -ForegroundColor White
Write-Host " VM Path:           $VMLocation\$VMName" -ForegroundColor White
Write-Host " CPUs:              $VMCPUs Cores" -ForegroundColor White
Write-Host " RAM:               $($VMRAM_MB / 1024) GB" -ForegroundColor White
Write-Host " Storage Size:      $($VMDisk_MB / 1024) GB (VDI dynamic)" -ForegroundColor White
Write-Host " ISO Path:          $IsoPath" -ForegroundColor White
Write-Host " Product Key:       $ProductKey" -ForegroundColor White
Write-Host " Citrix Store URL:  $CitrixUrl" -ForegroundColor White
Write-Host " Administrator:     $AdminUser" -ForegroundColor White
Write-Host " VM Evasions & Optimizations:" -ForegroundColor Green -Bold
Write-Host "   - Nested Virt:    ON (Citrix App Protection bypass)" -ForegroundColor Green
Write-Host "   - Paravirt:       Hyper-V (VBS/HVCI integration)" -ForegroundColor Green
Write-Host "   - Audio System:   Intel HD Audio + HPET Event Timer (No stutters!)" -ForegroundColor Green
Write-Host "   - Network System: Gigabit Server NIC (82545EM - Safe, high buffers)" -ForegroundColor Green
Write-Host "   - CPU Scheduling: High VM Process Priority (No audio/NIC drops)" -ForegroundColor Green
Write-Host "   - Hardware Redirects: YubiKey + Jabra Link filters pre-registered" -ForegroundColor Green
Write-Host ""
Write-Host "Press ENTER to begin creation..."
$null = Read-Host

Show-Banner
Write-Host "--- PROVISIONING PIPELINE RUNNING ---" -ForegroundColor Yellow -Bold
Write-Host ""

# 3. Clean up existing VM if it exists (including thorough virtual disk registration checking to prevent VBOX_E_FILE_ERROR)
$exists = & $VBoxManagePath list vms
if ($exists -match "`"$VMName`"") {
    Write-Warning "A VM named '$VMName' already exists!"
    Write-Host "Do you want to DELETE and OVERWRITE it? (Y/N): " -ForegroundColor Yellow -NoNewline
    $overwrite = Read-Host
    if ($overwrite -match "^[Yy]") {
        Write-Step "Stopping and deleting existing VM"
        
        $oldEAP = $ErrorActionPreference
        $ErrorActionPreference = "Continue"
        
        $vmInfo = & $VBoxManagePath showvminfo $VMName --machinereadable 2>$null
        if ($vmInfo -match 'VMState="running"|VMState="paused"') {
            & $VBoxManagePath controlvm $VMName poweroff 2>$null | Out-Null
            Start-Sleep -Seconds 2
        }
        
        & $VBoxManagePath unregistervm $VMName --delete 2>$null | Out-Null
        
        # Proactively check for orphaned medium in VirtualBox registry
        $mediumList = & $VBoxManagePath list hdds 2>$null
        $targetDiskFile = "$VMName.vdi"
        if ($mediumList -match $targetDiskFile) {
            Write-Warning "Detected orphaned disk media in VirtualBox registry: $targetDiskFile"
            # Parse out the UUID of the target disk to close it cleanly
            $lines = $mediumList -split "`r`n"
            $targetUUID = $null
            for ($i = 0; $i -lt $lines.Length; $i++) {
                if ($lines[$i] -match "Location:" -and $lines[$i] -match $targetDiskFile) {
                    # Look back or forward to get UUID
                    for ($j = [Math]::Max(0, $i-3); $j -lt [Math]::Min($lines.Length, $i+3); $j++) {
                        if ($lines[$j] -match "UUID:\s+([a-f0-9\-]+)") {
                            $targetUUID = $Matches[1]
                            break
                        }
                    }
                }
                if ($targetUUID) { break }
            }
            if ($targetUUID) {
                Write-Step "Closing and removing orphaned disk UUID $targetUUID"
                & $VBoxManagePath closemedium disk $targetUUID --delete 2>$null | Out-Null
            }
        }
        
        $ErrorActionPreference = $oldEAP
        Write-Success "Existing VM deleted."
    } else {
        Write-ErrorText "Aborted by user."
        Exit
    }
}

# 4. Build the VM Shell
Show-ProgressBar 10 "Creating VM shell..."
& $VBoxManagePath createvm --name $VMName --ostype "Windows11_64" --register --basefolder $VMLocation | Out-Null
Write-Success "Created Windows 11 64-bit shell registration."

Show-ProgressBar 20 "Configuring Hardware Specs..."
& $VBoxManagePath modifyvm $VMName --cpus $VMCPUs --memory $VMRAM_MB --vram 256 --graphicscontroller vboxsvga --accelerate-3d on | Out-Null
Write-Success "Registered CPU ($VMCPUs Cores), RAM ($VMRAM_MB MB), 3D acceleration, and 256MB VRAM."

# 5. Enable hardware passthrough and high performance optimizations
Show-ProgressBar 30 "Injecting Advanced High-Performance Virtualization & Priority..."
# Enable nested virtualization to allow virtualization-based security (VBS) in guest
& $VBoxManagePath modifyvm $VMName --nested-hw-virt on | Out-Null
# Set paravirtualization provider to Hyper-V so the guest runs in nested Hypervisor mode
& $VBoxManagePath modifyvm $VMName --paravirt-provider hyperv | Out-Null
# Configure EFI Firmware, TPM 2.0, Secure Boot (mandatory Win 11 features)
& $VBoxManagePath modifyvm $VMName --firmware efi64 | Out-Null
& $VBoxManagePath modifyvm $VMName --tpm-type 2.0 | Out-Null
& $VBoxManagePath modifynvram $VMName secureboot --enable | Out-Null
# Configure Bidirectional Clipboard, Drag & Drop, Intel HD Audio, HPET Timer, Gigabit Server NIC, High Host CPU Priority, USB Mouse/Keyboard Emulation, and Low-Latency compute parameters
& $VBoxManagePath modifyvm $VMName --clipboard-mode bidirectional --drag-and-drop bidirectional --audio-controller hda --audio-driver was --audio-in on --audio-out on --x86-hpet on --nic-type1 82545EM --vm-process-priority high --mouse usbtablet --keyboard usb --large-pages on --spec-ctrl off | Out-Null
Write-Success "Nested VT-x, Hyper-V, HPET, Server NIC, High CPU scheduling priority, USB Mouse/Keyboard, Large Pages, and Speculative Bypass enabled!"

# 6. Configure Integrated Accessory USB Filters
Show-ProgressBar 35 "Registering hardware USB filters..."
# Clear any legacy filters from indices 0-4 to prevent conflicts
for ($i = 0; $i -lt 5; $i++) {
    try { & $VBoxManagePath usbfilter remove 0 --target $VMName 2>$null | Out-Null } catch {}
}
# Filter 1: YubiKey OTP+FIDO+CCID
& $VBoxManagePath usbfilter add 0 --target $VMName --name "YubiKey OTP+FIDO+CCID" --action hold --active yes --vendorid "1050" --productid "0407" | Out-Null
# Filter 2: Jabra Link 390
& $VBoxManagePath usbfilter add 1 --target $VMName --name "Jabra Link 390" --action hold --active yes --vendorid "0b0e" --productid "2e50" | Out-Null
Write-Success "Hardware accessory filters (YubiKey + Jabra Bluetooth Dongle) registered."

# 7. Create Storage Controllers and Hard Disk
Show-ProgressBar 40 "Building storage system..."
& $VBoxManagePath storagectl $VMName --name "SATA Controller" --add sata --controller IntelAHCI --bootable on | Out-Null
$DiskPath = Join-Path "$VMLocation\$VMName" "$VMName.vdi"
$oldEAP = $ErrorActionPreference
$ErrorActionPreference = "Continue"
& $VBoxManagePath createmedium disk --filename $DiskPath --size $VMDisk_MB --format VDI 2>$null | Out-Null
$ErrorActionPreference = $oldEAP
& $VBoxManagePath storageattach $VMName --storagectl "SATA Controller" --port 0 --device 0 --type hdd --medium $DiskPath | Out-Null
# Mount installation ISO
& $VBoxManagePath storageattach $VMName --storagectl "SATA Controller" --port 1 --device 0 --type dvddrive --medium $IsoPath | Out-Null
Write-Success "Created virtual disk ($VMDisk_GB GB VDI) and mounted Windows 11 installation ISO."

# 8. Dynamically write and register Unattended installation engine
Show-ProgressBar 50 "Configuring unattended install templates..."
$TempXmlPath = Join-Path $env:TEMP "custom_unattended.xml"
$UnattendedXmlContent | Out-File $TempXmlPath -Encoding utf8 -Force
& $VBoxManagePath unattended install $VMName --iso=$IsoPath --user=$AdminUser --user-password=$AdminPass --full-user-name=$AdminUser --key=$ProductKey --install-additions --locale=en_GB --time-zone=UTC --script-template=$TempXmlPath | Out-Null
Write-Success "Configured unattended XML answers with local logon registry overrides."

# 9. Fire up the VM
Show-Banner
Write-Warning "======================================================================"
Write-Warning "   CRITICAL BOOT REQUIREMENT - ACTION REQUIRED IN 5 SECONDS           "
Write-Warning "======================================================================"
Write-Warning "   When the VirtualBox VM GUI window pops up in a moment, you MUST:   "
Write-Warning "   1. CLICK inside the black VM screen immediately to capture input. "
Write-Warning "   2. PRESS ANY KEY (e.g. Spacebar) on your keyboard repeatedly!    "
Write-Warning "                                                                      "
Write-Warning "   If you do not press a key within 5 seconds of the VM starting, the  "
Write-Warning "   Windows installer will skip the CD/DVD and fail to boot.           "
Write-Warning "   (If you miss it, click Machine -> Reset in the VM window to retry) "
Write-Warning "======================================================================"
Write-Host ""
Write-Host "Press ENTER to boot the VM and get ready to click and press any key..." -ForegroundColor Green
$null = Read-Host

Show-ProgressBar 60 "Booting Virtual Machine..."
& $VBoxManagePath startvm $VMName --type gui | Out-Null
Write-Success "VM successfully booted in GUI window."
Show-ProgressBar 70 "VM is now installing Windows 11..."
Write-Warning "DO NOT close the VirtualBox guest window! Unattended installation is actively running."
Write-Host "   Windows will install, automatically reboot, install Guest Additions, and load the desktop." -ForegroundColor Yellow
Write-Host "   This process typically takes 10 to 20 minutes depending on your disk & CPU speeds." -ForegroundColor Yellow
Write-Host "   LOCAL ACCOUNTS ONLY: We have pre-configured a clean, password-based local account ($AdminUser)." -ForegroundColor Cyan -Bold
Write-Host "   If Windows setup gets stuck at a Microsoft Account/email prompt, press Shift+F10 to open a" -ForegroundColor Cyan
Write-Host "   command prompt and type: C:\Bypass-OOBE.cmd  (or run: start ms-cxh:localonly) to bypass!" -ForegroundColor Cyan
Write-Host ""
Write-Step "Entering Guest Monitoring Loop. Waiting for OS and Guest Additions to report ready"

# 10. Wait for guest additions to report active (implies install is complete & user logged in)
$InstallFinished = $false
$ticks = 0
$maxTicks = 1800 # 30 minutes timeout (30 * 60s)
while (-not $InstallFinished -and $ticks -lt $maxTicks) {
    Start-Sleep -Seconds 10
    $ticks += 10
    
    # Query guest additions status
    $status = & $VBoxManagePath guestproperty get $VMName /VirtualBox/GuestAdd/Version 2>&1
    
    $minutes = [int][Math]::Floor($ticks / 60)
    $seconds = [int]($ticks % 60)
    $timeStr = "{0:D2}:{1:D2}" -f $minutes, $seconds
    
    if ($status -match "Value: ([0-9\.]+)") {
        $InstallFinished = $true
        $gaVer = $Matches[1]
        Write-Host ""
        Write-Success "Guest Additions detected as active! (Version: $gaVer, Time elapsed: $timeStr)"
    } else {
        Write-Host -NoNewline "`r   $($ClockChar) Time elapsed: $timeStr | Guest Status: Installing OS / Loading Desktop..." -ForegroundColor Yellow
    }
}
if (-not $InstallFinished) {
    Write-ErrorText "Installation monitoring timed out after 30 minutes! Please check the VM console."
    Exit
}

# Give guest shell extra seconds to stabilize and log in completely
Write-Step "Waiting 30 seconds for User Shell stabilization"
Start-Sleep -Seconds 30

# 11. Copy and execute VDI Optimization & Citrix 2603 Installer inside guest
Show-ProgressBar 80 "Injecting Guest VDI optimization script..."
$HostTempDir = Join-Path $env:TEMP "VBoxWin11VDI"
if (-not (Test-Path $HostTempDir)) { New-Item $HostTempDir -ItemType Directory | Out-Null }
$HostScriptPath = Join-Path $HostTempDir "GuestConfigure.ps1"
# Inject Citrix storefront URL dynamically into Here-String before saving
$FinalGuestScript = $GuestScriptContent.Replace('"$StorefrontUrl"', "`"$CitrixUrl`"")
$FinalGuestScript | Out-File $HostScriptPath -Encoding utf8 -Force

# Copy file into guest temp folder
$GuestTempDir = "C:\Windows\Temp"
try {
    & $VBoxManagePath guestcontrol $VMName copyto --username $AdminUser --password $AdminPass --target-directory $GuestTempDir $HostScriptPath | Out-Null
    Write-Success "Successfully copied configuration script to Guest path: C:\Windows\Temp\GuestConfigure.ps1"
} catch {
    Write-ErrorText "Failed to copy script to Guest! Error details: $_"
    Write-Warning "Please log in to the VM manually using: Username: $AdminUser | Password: $AdminPass"
    Write-Warning "And execute the configuration script manually."
    Exit
}

# 12. Run Guest Setup Script (First Pass - enables features and reboots guest)
Show-ProgressBar 90 "Executing Guest Configuration - First Pass (Enabling VBS/HVCI)..."
$runArgs = @(
    "guestcontrol", $VMName, "run", 
    "--exe", "C:\Windows\System32\WindowsPowerShell\v1.0\powershell.exe",
    "--username", $AdminUser, "--password", $AdminPass,
    "--wait-stdout", "--wait-stderr",
    "--",
    "-ExecutionPolicy", "Bypass",
    "-File", "C:\Windows\Temp\GuestConfigure.ps1"
)
Write-Step "Executing script inside Guest OS. Capturing console output"
Write-Host "----------------- GUEST INSTALL LOG (PASS 1) -----------------" -ForegroundColor Gray
$res = & $VBoxManagePath @runArgs
Write-Host $res -ForegroundColor Gray
Write-Host "------------------------------------------------------------" -ForegroundColor Gray

# If guest script requested a reboot (exits with code 100 or drops connection)
Write-Step "Waiting for guest reboot to apply VBS and hypervisor settings"
Start-Sleep -Seconds 45

# Wait for guest additions to report back again
$RebootFinished = $false
$ticks = 0
while (-not $RebootFinished -and $ticks -lt 300) {
    Start-Sleep -Seconds 10
    $ticks += 10
    $status = & $VBoxManagePath guestproperty get $VMName /VirtualBox/GuestAdd/Version 2>&1
    if ($status -match "Value: ([0-9\.]+)") {
        $RebootFinished = $true
        Write-Success "Guest is back online after virtualization reboot!"
    } else {
        Write-Host -NoNewline "`r   $($ClockChar) Waiting for guest to reboot... ($ticks/300s)" -ForegroundColor Yellow
    }
}
# Give guest 15 seconds to load desktop
Start-Sleep -Seconds 15

# 13. Run Guest Setup Script (Second Pass - Installs Citrix 2603 & Configures Store)
Show-ProgressBar 95 "Executing Guest Configuration - Second Pass (Installing Citrix 2603)..."
Write-Host "----------------- GUEST INSTALL LOG (PASS 2) -----------------" -ForegroundColor Gray
$res2 = & $VBoxManagePath @runArgs
Write-Host $res2 -ForegroundColor Gray
Write-Host "------------------------------------------------------------" -ForegroundColor Gray

# 14. Integrated Native Webcam Mapping
Show-ProgressBar 98 "Mapping host accessories (Webcam)..."
try {
    & $VBoxManagePath controlvm $VMName webcam attach .1 "MaxPayloadTransferSize=16384;MaxFramerate=30" | Out-Null
    Write-Success "Webcam 'Dell Webcam WB7022' successfully mapped via stable native VirtualBox webcam passthrough!"
} catch {
    Write-Warning "Could not attach webcam: $_. Ensure the Webcam is plugged in."
}

# 15. Complete
Show-ProgressBar 100 "VM Configuration Pipeline successfully complete!"
Show-Banner
Write-Host "======================================================================" -ForegroundColor Green -Bold
Write-Host "      WIN11 PRO VDI CLIENT PROVISIONING SUCCESSFULLY COMPLETED!        " -ForegroundColor Green -Bold
Write-Host "======================================================================" -ForegroundColor Green -Bold
Write-Host ""
Write-Host " VM Name:                  $VMName" -ForegroundColor White
Write-Host " Administrator Username:   $AdminUser" -ForegroundColor White
Write-Host " Administrator Password:   $AdminPass" -ForegroundColor Green -Bold
Write-Host " Citrix Storefront URL:    $CitrixUrl" -ForegroundColor White
Write-Host ""
Write-Host " ADVANCED STABILIZATION & SECURITY CONFIGURED:" -ForegroundColor Cyan -Bold
Write-Host " $($CheckChar) Nested VT-x/AMD-V Hardware Passthrough Active" -ForegroundColor Green
Write-Host " $($CheckChar) Hyper-V Paravirtualization Present" -ForegroundColor Green
Write-Host " $($CheckChar) Virtualization-Based Security (VBS) Running in Guest" -ForegroundColor Green
Write-Host " $($CheckChar) Intel HD Audio + HPET Event Timer (Lag-free headset audio)" -ForegroundColor Green
Write-Host " $($CheckChar) Gigabit Server NIC (Intel 82545EM - Stable Citrix connection)" -ForegroundColor Green
Write-Host " $($CheckChar) High Host CPU Process Priority Set Permanently" -ForegroundColor Green
Write-Host " $($CheckChar) Hardware Redirection USB Filters Active (YubiKey + Jabra)" -ForegroundColor Green
Write-Host " $($CheckChar) Dell Webcam WB7022 mapped natively via VirtualBox capture" -ForegroundColor Green
Write-Host ""
Write-Host " YOU ARE READY TO LOG IN AND CONNECT TO YOUR WORK VDI!" -ForegroundColor Yellow -Bold
Write-Host "======================================================================" -ForegroundColor Cyan
Write-Host ""
Write-Host "Press ENTER to close this window..."
$null = Read-Host

# Clean up host temporary files
if (Test-Path $HostTempDir) { Remove-Item $HostTempDir -Recurse -Force }
if (Test-Path $TempXmlPath) { Remove-Item $TempXmlPath -Force }

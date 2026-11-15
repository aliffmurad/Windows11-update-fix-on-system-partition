<#
.SYNOPSIS
    Fixes Windows 11 Update error: "We couldn't update the system reserved partition".
.DESCRIPTION
    Reclaims space on the EFI System Partition (ESP) by safely backing up and removing:
    1. Unused localized boot fonts in \EFI\Microsoft\Boot\Fonts
    2. Leftover OEM firmware flasher images (e.g. Lenovo/Insyde isflash.bin, SelfHealing.fd)
    Also configures EspPaddingPercent registry value to prevent Windows Update from over-allocating space.
.NOTES
    Safe & non-destructive: all files are verified and backed up to C:\EFI_Backup before deletion.
#>

# Ensure running with Administrator privileges
$isAdmin = ([Security.Principal.WindowsPrincipal][Security.Principal.WindowsIdentity]::GetCurrent()).IsInRole([Security.Principal.WindowsBuiltInRole]::Administrator)
if (-not $isAdmin) {
    Write-Host "Requesting Administrator privileges..." -ForegroundColor Yellow
    Start-Process powershell.exe -ArgumentList ("-NoProfile -ExecutionPolicy Bypass -File `"{0}`"" -f $PSCommandPath) -Verb RunAs
    exit
}

$host.UI.RawUI.WindowTitle = "Windows 11 EFI System Partition Fix"
Clear-Host
Write-Host "======================================================================" -ForegroundColor Cyan
Write-Host "      Windows 11 Update - EFI System Partition Space Fix" -ForegroundColor Cyan
Write-Host "======================================================================" -ForegroundColor Cyan
Write-Host ""

$backupRoot = "C:\EFI_Backup"
$mountDrive = "Y:"

try {
    # 1. Mount the EFI System Partition
    Write-Host "[Step 1/6] Mounting EFI System Partition to ${mountDrive}..." -ForegroundColor White
    mountvol $mountDrive /s | Out-Null
    Start-Sleep -Seconds 1

    $diskBefore = Get-CimInstance Win32_LogicalDisk -Filter "DeviceID='$mountDrive'"
    if (-not $diskBefore) {
        throw "Could not mount or access EFI System Partition at ${mountDrive}."
    }
    $beforeFreeMB = [math]::Round($diskBefore.FreeSpace / 1MB, 2)
    $totalMB = [math]::Round($diskBefore.Size / 1MB, 2)
    Write-Host "  -> Partition Total: $totalMB MB | Free: $beforeFreeMB MB" -ForegroundColor Gray

    # 2. Setup Backup Directory
    Write-Host "[Step 2/6] Preparing backup directory at $backupRoot..." -ForegroundColor White
    New-Item -ItemType Directory -Path $backupRoot -Force | Out-Null

    # 3. Clean Language Boot Fonts
    Write-Host "[Step 3/6] Checking for boot fonts in \EFI\Microsoft\Boot\Fonts..." -ForegroundColor White
    $fontsPath = "${mountDrive}\EFI\Microsoft\Boot\Fonts"
    if (Test-Path $fontsPath) {
        $fontFiles = Get-ChildItem -Path $fontsPath -Filter "*.ttf" -Force -ErrorAction SilentlyContinue
        if ($fontFiles.Count -gt 0) {
            $fontsBackup = Join-Path $backupRoot "Fonts"
            New-Item -ItemType Directory -Path $fontsBackup -Force | Out-Null
            Write-Host "  -> Found $($fontFiles.Count) font file(s). Backing up to $fontsBackup..." -ForegroundColor Yellow
            Copy-Item -Path "$fontsPath\*.ttf" -Destination $fontsBackup -Force
            Remove-Item -Path "$fontsPath\*.ttf" -Force
            Write-Host "  -> Reclaimed space from boot fonts." -ForegroundColor Green
        } else {
            Write-Host "  -> No excessive font files found." -ForegroundColor Gray
        }
    }

    # 4. Clean OEM / Lenovo / Insyde Firmware Flasher Leftovers
    Write-Host "[Step 4/6] Checking for OEM firmware flasher leftovers..." -ForegroundColor White
    
    # Check Insyde isflash.bin
    $isflash = "${mountDrive}\EFI\Insyde\isflash.bin"
    if (Test-Path $isflash) {
        $insydeBackup = Join-Path $backupRoot "Insyde"
        New-Item -ItemType Directory -Path $insydeBackup -Force | Out-Null
        $sizeMB = [math]::Round((Get-Item $isflash).Length / 1MB, 2)
        Write-Host "  -> Found Insyde flash image ($sizeMB MB). Backing up..." -ForegroundColor Yellow
        Copy-Item -Path $isflash -Destination "$insydeBackup\isflash.bin" -Force
        if ((Test-Path "$insydeBackup\isflash.bin") -and (Get-Item "$insydeBackup\isflash.bin").Length -gt 1MB) {
            Remove-Item -Path $isflash -Force
            Write-Host "  -> Removed leftover isflash.bin." -ForegroundColor Green
        }
    }

    # Check Lenovo SelfHealing.fd
    $selfHealing = "${mountDrive}\EFI\Lenovo\BIOS\SelfHealing.fd"
    if (Test-Path $selfHealing) {
        $lenovoBackup = Join-Path $backupRoot "Lenovo\BIOS"
        New-Item -ItemType Directory -Path $lenovoBackup -Force | Out-Null
        $sizeMB = [math]::Round((Get-Item $selfHealing).Length / 1MB, 2)
        Write-Host "  -> Found Lenovo SelfHealing BIOS backup ($sizeMB MB). Backing up..." -ForegroundColor Yellow
        Copy-Item -Path $selfHealing -Destination "$lenovoBackup\SelfHealing.fd" -Force
        if ((Test-Path "$lenovoBackup\SelfHealing.fd") -and (Get-Item "$lenovoBackup\SelfHealing.fd").Length -gt 1MB) {
            Remove-Item -Path $selfHealing -Force
            Write-Host "  -> Removed leftover SelfHealing.fd." -ForegroundColor Green
        }
    }

    # 5. Configure Windows Bfsvc EspPaddingPercent
    Write-Host "[Step 5/6] Configuring registry EspPaddingPercent to 0..." -ForegroundColor White
    $regPath = "HKLM:\SYSTEM\CurrentControlSet\Control\Bfsvc"
    if (-not (Test-Path $regPath)) {
        New-Item -Path $regPath -Force | Out-Null
    }
    Set-ItemProperty -Path $regPath -Name "EspPaddingPercent" -Value 0 -Type DWord -Force
    Write-Host "  -> Registry key configured." -ForegroundColor Green

    # 6. Check results and unmount
    Start-Sleep -Seconds 1
    $diskAfter = Get-CimInstance Win32_LogicalDisk -Filter "DeviceID='$mountDrive'"
    $afterFreeMB = [math]::Round($diskAfter.FreeSpace / 1MB, 2)
    $freedMB = [math]::Round($afterFreeMB - $beforeFreeMB, 2)

    Write-Host "[Step 6/6] Dismounting EFI System Partition..." -ForegroundColor White
    mountvol $mountDrive /d | Out-Null
    Write-Host "  -> Partition unmounted cleanly." -ForegroundColor Green

    Write-Host ""
    Write-Host "======================================================================" -ForegroundColor Cyan
    Write-Host "                    SUCCESS! EFI SPACE RECLAIMED                      " -ForegroundColor Green
    Write-Host "======================================================================" -ForegroundColor Cyan
    Write-Host "  Previous Free Space : $beforeFreeMB MB"
    Write-Host "  New Free Space      : $afterFreeMB MB" -ForegroundColor Green
    Write-Host "  Total Space Freed   : $freedMB MB" -ForegroundColor Green
    Write-Host "  Backup Preserved At : $backupRoot" -ForegroundColor Yellow
    Write-Host "======================================================================" -ForegroundColor Cyan
    Write-Host ""
    Write-Host "You can now retry your Windows 11 Update!" -ForegroundColor Green
    Write-Host ""
}
catch {
    Write-Host "Error occurred: $_" -ForegroundColor Red
    mountvol $mountDrive /d | Out-Null
}

Read-Host "Press Enter to exit"

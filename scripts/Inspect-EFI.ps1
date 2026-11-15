<#
.SYNOPSIS
    Inspects files and directory sizes on the EFI System Partition (ESP).
#>

$isAdmin = ([Security.Principal.WindowsPrincipal][Security.Principal.WindowsIdentity]::GetCurrent()).IsInRole([Security.Principal.WindowsBuiltInRole]::Administrator)
if (-not $isAdmin) {
    Write-Host "Requesting Administrator privileges..." -ForegroundColor Yellow
    Start-Process powershell.exe -ArgumentList ("-NoProfile -ExecutionPolicy Bypass -File `"{0}`"" -f $PSCommandPath) -Verb RunAs
    exit
}

$host.UI.RawUI.WindowTitle = "EFI System Partition Inspector"
Clear-Host
Write-Host "======================================================================" -ForegroundColor Cyan
Write-Host "                EFI System Partition (ESP) Inspector                  " -ForegroundColor Cyan
Write-Host "======================================================================" -ForegroundColor Cyan
Write-Host ""

$mountDrive = "Y:"

try {
    Write-Host "Mounting EFI System Partition to ${mountDrive}..." -ForegroundColor White
    mountvol $mountDrive /s | Out-Null
    Start-Sleep -Seconds 1

    Write-Host "`n--- Overall Volume Status ---" -ForegroundColor Cyan
    Get-CimInstance Win32_LogicalDisk -Filter "DeviceID='$mountDrive'" | Select-Object DeviceID, @{N='Total_MB';E={[math]::Round($_.Size/1MB,2)}}, @{N='Free_MB';E={[math]::Round($_.FreeSpace/1MB,2)}} | Format-Table -AutoSize

    Write-Host "--- Directory Size Breakdown ---" -ForegroundColor Cyan
    Get-ChildItem -Path "${mountDrive}\EFI" -Directory -Force -ErrorAction SilentlyContinue | ForEach-Object {
        $d = $_
        $files = Get-ChildItem -Path $d.FullName -Recurse -File -Force -ErrorAction SilentlyContinue
        $size = ($files | Measure-Object -Property Length -Sum).Sum
        [PSCustomObject]@{
            Directory   = $d.FullName
            TotalFiles  = $files.Count
            TotalSizeMB = [math]::Round($size / 1MB, 2)
        }
    } | Format-Table -AutoSize

    Write-Host "--- Largest Files in EFI Partition ---" -ForegroundColor Cyan
    Get-ChildItem -Path "${mountDrive}\" -Recurse -File -Force -ErrorAction SilentlyContinue | 
        Sort-Object Length -Descending | 
        Select-Object -First 15 | 
        Select-Object @{N='File';E={$_.FullName}}, @{N='SizeMB';E={[math]::Round($_.Length/1MB, 2)}}, LastWriteTime | 
        Format-Table -AutoSize

    Write-Host "Dismounting ${mountDrive}..." -ForegroundColor White
    mountvol $mountDrive /d | Out-Null
    Write-Host "Partition unmounted cleanly.`n" -ForegroundColor Green
}
catch {
    Write-Host "Error: $_" -ForegroundColor Red
    mountvol $mountDrive /d | Out-Null
}

Read-Host "Press Enter to exit"

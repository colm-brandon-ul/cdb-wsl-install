# Global Variables
$distro = "Ubuntu-22.04"
$drives = Get-PSDrive -PSProvider FileSystem | Where-Object {$_.Free -ne $null}
$largestDrive = $drives | Sort-Object -Property Free -Descending | Select-Object -First 1

# Define paths
$wslRoot = "$($largestDrive.Root)wsl"
$wslBackup = "$($largestDrive.Root)wsl-backup"

Write-Output "Starting uninstall process for $distro and associated components..."

# Stop WSL processes
Write-Output "Stopping WSL..."
wsl.exe --shutdown

# Unregister the distribution
Write-Output "Removing WSL distribution..."
wsl.exe --unregister $distro

Write-Output "Uninstall completed successfully. The following actions were performed:"
Write-Output "1. Stopped all WSL processes"
Write-Output "2. Removed the $distro distribution"
Write-Output "`nNote: If you want to completely remove WSL from your system, you can also run:"
Write-Output "wsl --uninstall"

Read-Host "Press Enter to exit"
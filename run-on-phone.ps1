# One-command run for ClipForge AI on a connected Android device/emulator.
#
#   ./run-on-phone.ps1            # auto-picks the connected device
#   ./run-on-phone.ps1 fa4b6223  # target a specific device id (see: adb devices)
#
# Uses an isolated Gradle home (C:\src\gh) so the build does NOT fight the
# shared ~/.gradle cache that the IDE's Java language server keeps locked, and
# sets up an adb tunnel so the app can reach the local backend at localhost:8000.
param([string]$DeviceId)

$ErrorActionPreference = "Stop"
Set-Location $PSScriptRoot

$env:GRADLE_USER_HOME = "C:\src\gh"
$flutter = "C:\src\flutter\bin\flutter.bat"
$adb = "$env:LOCALAPPDATA\Android\Sdk\platform-tools\adb.exe"

# Tunnel the device's localhost:8000 -> host backend (works on device + emulator).
if ($DeviceId) { & $adb -s $DeviceId reverse tcp:8000 tcp:8000 } else { & $adb reverse tcp:8000 tcp:8000 }
Write-Host "adb reverse 8000 set (start the backend with backend/run.ps1)" -ForegroundColor Cyan

if ($DeviceId) {
    & $flutter run -d $DeviceId
} else {
    & $flutter run
}

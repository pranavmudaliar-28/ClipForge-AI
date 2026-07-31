# Reliable one-command deploy for ClipForge AI on the vivo (or any Android device).
#
#   ./run-on-phone.ps1 -Wireless          # first time: USB plugged in ONCE to enable Wi-Fi ADB
#   ./run-on-phone.ps1 10.113.43.150:5555 # subsequent: deploy straight over Wi-Fi (unplugged)
#   ./run-on-phone.ps1 fa4b6223           # force a specific USB device id
#   ./run-on-phone.ps1                     # auto-pick the first connected device
#
# WHY THIS EXISTS (this machine's quirks):
#  - This PC's USB link to the vivo CORRUPTS large transfers: every `adb push` of
#    the ~254 MB debug APK arrives with a different md5, so `flutter run`'s streamed
#    install fails with INSTALL_PARSE_FAILED_NO_CERTIFICATES ("digest did not verify").
#    => We deploy over WIRELESS adb (TCP is checksummed) and VERIFY the md5 before
#       installing, retrying if a transfer is ever bad.
#  - The IDE's Java LS locks the shared ~/.gradle cache, so we build with an isolated
#    GRADLE_USER_HOME (C:\src\gh).
#  - adb reverse tunnels the device's localhost:8000 -> host backend.
param(
    [string]$DeviceId,          # USB serial or ip:port; auto-picks if omitted
    [switch]$Wireless,          # enable/verify Wi-Fi ADB from a USB-connected phone
    [int]$Port = 5555,
    [switch]$SkipBuild          # deploy the existing APK without rebuilding
)

$ErrorActionPreference = "Stop"
Set-Location $PSScriptRoot

$env:GRADLE_USER_HOME = "C:\src\gh"
$flutter = "C:\src\flutter\bin\flutter.bat"
$adb = "$env:LOCALAPPDATA\Android\Sdk\platform-tools\adb.exe"
$pkg = "com.slasheasy.clipforge_ai"

function Get-FirstDevice {
    (& $adb devices) -split "`n" |
        Where-Object { $_ -match "\tdevice$" } |
        ForEach-Object { ($_ -split "\s+")[0] } |
        Select-Object -First 1
}

# 1) Optionally bring up wireless ADB (bypasses the corrupting USB data path).
if ($Wireless) {
    $usb = Get-FirstDevice
    if (-not $usb) { throw "Plug the phone in over USB once so I can enable wireless ADB." }
    $ipLine = & $adb -s $usb shell "ip -f inet addr show wlan0"
    $m = [regex]::Match(($ipLine -join "`n"), "inet (\d+\.\d+\.\d+\.\d+)")
    if (-not $m.Success) { throw "Phone has no Wi-Fi IP - connect it to the same Wi-Fi as this PC." }
    $ip = $m.Groups[1].Value
    & $adb -s $usb tcpip $Port | Out-Null
    Start-Sleep -Seconds 2   # let adbd restart in TCP mode
    & $adb connect "${ip}:$Port" | Out-Null
    $DeviceId = "${ip}:$Port"
    Write-Host "Wireless ADB up: $DeviceId  (you can unplug the USB cable now)" -ForegroundColor Cyan
}

# 2) Resolve the target device.
if (-not $DeviceId) { $DeviceId = Get-FirstDevice }
if (-not $DeviceId) { throw "No device found. Run with -Wireless (USB plugged once) or plug in the phone." }
Write-Host "Target: $DeviceId" -ForegroundColor Cyan

# 3) Backend tunnel (device localhost:8000 -> host).
& $adb -s $DeviceId reverse tcp:8000 tcp:8000 | Out-Null
Write-Host "adb reverse 8000 set (start backend with backend/run.ps1)" -ForegroundColor Cyan

# 4) Build (unless skipped).
$apk = Join-Path $PSScriptRoot "build\app\outputs\flutter-apk\app-debug.apk"
if (-not $SkipBuild) {
    Write-Host "Building debug APK..." -ForegroundColor Cyan
    & $flutter build apk --debug
}
if (-not (Test-Path $apk)) { throw "APK not found at $apk (build first, or drop -SkipBuild)." }

# 5) Verified install: push to a temp path, confirm the device copy matches the host
#    byte-for-byte, then install from there. Guards against transfer corruption.
$hostMd5 = (Get-FileHash -Algorithm MD5 $apk).Hash.ToLower()
$dest = "/data/local/tmp/clipforge.apk"
$ok = $false
for ($i = 1; $i -le 4; $i++) {
    & $adb -s $DeviceId push $apk $dest | Out-Null
    $devMd5 = ((& $adb -s $DeviceId shell md5sum $dest) -split "\s+")[0]
    if ($devMd5 -eq $hostMd5) { $ok = $true; break }
    Write-Host "transfer mismatch (attempt $i): $devMd5 != $hostMd5 - retrying" -ForegroundColor Yellow
}
if (-not $ok) {
    throw "APK transfer kept corrupting on $DeviceId. If this is a USB device, use -Wireless (or a different cable/port)."
}
& $adb -s $DeviceId shell pm install -r -d $dest
& $adb -s $DeviceId shell rm -f $dest

# 6) Launch.
& $adb -s $DeviceId shell monkey -p $pkg -c android.intent.category.LAUNCHER 1 | Out-Null
Write-Host "Launched $pkg on $DeviceId" -ForegroundColor Green
Write-Host "Logs: & '$adb' -s $DeviceId logcat -s flutter:V" -ForegroundColor DarkGray

# Capture Play Store phone screenshots (Windows).
$ErrorActionPreference = "Stop"
${env:ProgramFiles(x86)} = "C:\Program Files (x86)"

$Root = Split-Path -Parent $PSScriptRoot
Set-Location $Root

$Flutter = "C:\Users\shubh\AppData\Local\flutter\bin\flutter.bat"
if (-not (Test-Path $Flutter)) {
    $Flutter = "flutter"
}

& $Flutter pub get
if ($LASTEXITCODE -ne 0) { exit $LASTEXITCODE }

$device = $null
$adb = Get-Command adb -ErrorAction SilentlyContinue
if ($adb) {
    $lines = adb devices | Select-Object -Skip 1
    foreach ($line in $lines) {
        if ($line -match "^\s*(\S+)\s+device\s*$") {
            $device = $Matches[1]
            break
        }
    }
}

$out = "fastlane\metadata\android\en-IN\images\phoneScreenshots"
New-Item -ItemType Directory -Force -Path $out | Out-Null

if ($device) {
    Write-Host "Capturing on Android device $device"
    & $Flutter drive `
        --driver=test_driver/integration_test.dart `
        --target=integration_test/store_screenshots_test.dart `
        -d $device
    if ($LASTEXITCODE -ne 0) { exit $LASTEXITCODE }
} else {
    Write-Host "No Android emulator/device; rasterizing widgets via flutter test (VM)"
    & $Flutter test test/widget/store_screenshot_capture_test.dart
    if ($LASTEXITCODE -ne 0) { exit $LASTEXITCODE }
}

python tool\pad_store_screenshots.py
if ($LASTEXITCODE -ne 0) { exit $LASTEXITCODE }
python tool\store_assets\render_feature_graphic.py
if ($LASTEXITCODE -ne 0) { exit $LASTEXITCODE }
python tool\verify_store_images.py
if ($LASTEXITCODE -ne 0) { exit $LASTEXITCODE }

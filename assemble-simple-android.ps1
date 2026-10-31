param(
    [switch]$Install,
    [switch]$SkipLint
)

$ErrorActionPreference = "Stop"
$projectDir = Join-Path $PSScriptRoot "SimpleAndroid"
$gradlew = Join-Path $projectDir "gradlew.bat"

if (-not (Test-Path $gradlew)) {
    throw "SimpleAndroid was not found or gradlew.bat is missing: $projectDir"
}

Push-Location $projectDir
try {
    Write-Host "Cleaning project..." -ForegroundColor Cyan
    & $gradlew clean
    if ($LASTEXITCODE -ne 0) { throw "Gradle clean failed." }

    Write-Host "Formatting Kotlin and imports with KtLint..." -ForegroundColor Cyan
    & $gradlew ktlintFormat
    if ($LASTEXITCODE -ne 0) { throw "Kotlin formatting failed." }

    Write-Host "Checking Kotlin style..." -ForegroundColor Cyan
    & $gradlew ktlintCheck
    if ($LASTEXITCODE -ne 0) { throw "Kotlin lint failed." }

    Write-Host "Compiling and checking Compose sources..." -ForegroundColor Cyan
    & $gradlew assembleDebug
    if ($LASTEXITCODE -ne 0) { throw "Debug build failed. Check the compiler errors above." }

    if (-not $SkipLint) {
        Write-Host "Running Android lint..." -ForegroundColor Cyan
        & $gradlew lintDebug
        if ($LASTEXITCODE -ne 0) {
            Write-Warning "Lint reported issues. Review app/build/reports/lint-results-debug.html."
        }
    }

    $apk = Join-Path $projectDir "app/build/outputs/apk/debug/app-debug.apk"
    if (Test-Path $apk) {
        Write-Host "Build succeeded: $apk" -ForegroundColor Green
    }

    if ($Install) {
        Write-Host "Installing debug APK..." -ForegroundColor Cyan
        & $gradlew installDebug
        if ($LASTEXITCODE -ne 0) {
            throw "Installation failed. Run 'adb devices' and authorize the device."
        }
    }
}
finally {
    Pop-Location
}

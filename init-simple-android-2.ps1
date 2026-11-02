param(
    [string]$ProjectName = "SimpleAndroid",
    [string]$PackageName = "com.example.simpleandroid",
    [string]$OutputPath = (Get-Location).Path,
    [string]$GradleVersion = "8.11.1",
    [switch]$Force
)

$ErrorActionPreference = "Stop"
if ($GradleVersion -notmatch '^\d+\.\d+(\.\d+)?$') {
    throw 'GradleVersion must be a numeric version such as 8.11.1.'
}

# PowerShell 7 on Linux, macOS, and Windows.
$isWindowsHost = [System.IO.Path]::DirectorySeparatorChar -eq '\'

function Find-Jdk17 {
    $candidates = @()
    if ($env:JAVA_HOME) { $candidates += $env:JAVA_HOME }
    $roots = if ($isWindowsHost) {
        @("$env:ProgramFiles/Microsoft", "$env:ProgramFiles/Java", "$env:LOCALAPPDATA/Programs/Microsoft")
    } else {
        @('/usr/lib/jvm', '/usr/java', '/Library/Java/JavaVirtualMachines')
    }
    foreach ($root in $roots) {
        if (Test-Path -LiteralPath $root) {
            $candidates += @(Get-ChildItem -LiteralPath $root | Where-Object { $_.PSIsContainer } | ForEach-Object {
                if (Test-Path -LiteralPath (Join-Path $_.FullName 'Contents/Home')) {
                    Join-Path $_.FullName 'Contents/Home'
                } else { $_.FullName }
            })
        }
    }
    $javaCommand = Get-Command java -CommandType Application -ErrorAction SilentlyContinue | Select-Object -First 1
    if ($javaCommand) {
        $resolvedJava = (Get-Item -LiteralPath $javaCommand.Source).ResolveLinkTarget($true)
        $javaPath = if ($resolvedJava) { $resolvedJava.FullName } else { $javaCommand.Source }
        $candidates += Split-Path (Split-Path $javaPath -Parent) -Parent
    }
    foreach ($candidate in ($candidates | Select-Object -Unique)) {
        $java = Join-Path $candidate $(if ($isWindowsHost) { 'bin/java.exe' } else { 'bin/java' })
        $javac = Join-Path $candidate $(if ($isWindowsHost) { 'bin/javac.exe' } else { 'bin/javac' })
        if ((Test-Path -LiteralPath $java) -and (Test-Path -LiteralPath $javac)) {
            $version = (& $java -version 2>&1 | Out-String)
            if ($LASTEXITCODE -eq 0 -and $version -match 'version "17\.') { return $candidate }
        }
    }
    return $null
}

$jdk17 = Find-Jdk17
if (-not $jdk17) {
    throw 'JDK 17 is required. On Linux Mint/Ubuntu, run: sudo apt install openjdk-17-jdk. On Windows or macOS, install JDK 17 and set JAVA_HOME, then rerun this script.'
}

if ($PackageName -notmatch '^[A-Za-z_][A-Za-z0-9_]*(\.[A-Za-z_][A-Za-z0-9_]*)+$') {
    throw "PackageName must look like com.example.app"
}

$projectDir = Join-Path $OutputPath $ProjectName
if ((Test-Path $projectDir) -and -not $Force) {
    throw "Target directory already exists: $projectDir. Use -Force to overwrite generated files."
}

New-Item -ItemType Directory -Force -Path `
    (Join-Path $projectDir "app/src/main/java/$($PackageName.Replace('.', '/'))"), `
    (Join-Path $projectDir "app/src/main/res/values") | Out-Null

if ($Force) {
    Remove-Item -LiteralPath (Join-Path $projectDir "app/src/main/java/$($PackageName.Replace('.', '/'))/MainActivity.java") -Force -ErrorAction SilentlyContinue
    Remove-Item -LiteralPath (Join-Path $projectDir "app/src/main/res/layout") -Recurse -Force -ErrorAction SilentlyContinue
    Remove-Item -LiteralPath (Join-Path $projectDir "app/src/main/res/values/themes.xml") -Force -ErrorAction SilentlyContinue
    Remove-Item -LiteralPath (Join-Path $projectDir "app/src/main/res/values/strings.xml") -Force -ErrorAction SilentlyContinue
}

function Write-ProjectFile([string]$RelativePath, [string]$Content) {
    $path = Join-Path $projectDir $RelativePath
    $parent = Split-Path $path -Parent
    New-Item -ItemType Directory -Force -Path $parent | Out-Null
    [System.IO.File]::WriteAllText($path, $Content, (New-Object System.Text.UTF8Encoding($false)))
}

function Write-AsciiProjectFile([string]$RelativePath, [string]$Content) {
    $path = Join-Path $projectDir $RelativePath
    $parent = Split-Path $path -Parent
    New-Item -ItemType Directory -Force -Path $parent | Out-Null
    [System.IO.File]::WriteAllText($path, $Content, [System.Text.Encoding]::ASCII)
}

$packagePath = $PackageName.Replace('.', '/')

Write-ProjectFile "settings.gradle" @"
pluginManagement { repositories { google(); mavenCentral(); gradlePluginPortal() } }
dependencyResolutionManagement {
    repositoriesMode.set(RepositoriesMode.FAIL_ON_PROJECT_REPOS)
    repositories { google(); mavenCentral() }
}
rootProject.name = '$ProjectName'
include ':app'
"@

Write-ProjectFile "build.gradle" @"
plugins {
    id 'com.android.application' version '8.7.3' apply false
    id 'org.jetbrains.kotlin.android' version '2.0.21' apply false
    id 'org.jetbrains.kotlin.plugin.compose' version '2.0.21' apply false
    id 'com.google.dagger.hilt.android' version '2.51.1' apply false
    id 'com.google.devtools.ksp' version '2.0.21-1.0.25' apply false
    id 'org.jlleitschuh.gradle.ktlint' version '12.1.2' apply false
}
"@

Write-ProjectFile "gradle.properties" @"
org.gradle.jvmargs=-Xmx2048m -Dfile.encoding=UTF-8
org.gradle.java.home=$($jdk17.Replace('\', '/'))
android.useAndroidX=true
android.nonTransitiveRClass=true
android.useK2=true
"@

Write-ProjectFile "gradle/wrapper/gradle-wrapper.properties" @"
distributionBase=GRADLE_USER_HOME
distributionPath=wrapper/dists
distributionUrl=https\://services.gradle.org/distributions/gradle-$GradleVersion-bin.zip
networkTimeout=10000
zipStoreBase=GRADLE_USER_HOME
zipStorePath=wrapper/dists
"@

Write-AsciiProjectFile "gradlew.bat" @"
@echo off
set "JAVA_HOME=$jdk17"
set "GRADLE_USER_HOME=%~dp0..\.gradle-user-home"
call "%~dp0..\.gradle-wrapper-cache\$GradleVersion\gradle-$GradleVersion\bin\gradle.bat" %*
exit /b %ERRORLEVEL%
"@

$shellLauncher = @'
#!/bin/sh
APP_HOME=$(CDPATH= cd -- "$(dirname -- "$0")" && pwd -P)
export JAVA_HOME='__JAVA_HOME__'
export GRADLE_USER_HOME="$APP_HOME/../.gradle-user-home"
exec "$APP_HOME/../.gradle-wrapper-cache/__VERSION__/gradle-__VERSION__/bin/gradle" "$@"
'@
$shellJavaHome = $jdk17.Replace("'", "'\''")
Write-AsciiProjectFile "gradlew" ($shellLauncher.Replace('__JAVA_HOME__', $shellJavaHome).Replace('__VERSION__', $GradleVersion))
if (-not $isWindowsHost) {
    & chmod +x (Join-Path $projectDir 'gradlew')
    if ($LASTEXITCODE -ne 0) { throw 'Could not make gradlew executable.' }
}

$wrapperUrl = "https://services.gradle.org/distributions/gradle-$GradleVersion-bin.zip"
$cacheDir = Join-Path $OutputPath ".gradle-wrapper-cache/$GradleVersion"
$cachedZip = Join-Path $cacheDir "gradle-$GradleVersion-bin.zip"
$cachedDistribution = Join-Path $cacheDir "gradle-$GradleVersion"
$gradleExecutable = Join-Path $cachedDistribution $(if ($isWindowsHost) { 'bin/gradle.bat' } else { 'bin/gradle' })
New-Item -ItemType Directory -Force -Path $cacheDir | Out-Null
if (-not (Test-Path -LiteralPath $gradleExecutable)) {
    if (-not (Test-Path -LiteralPath $cachedZip)) {
        $partialZip = "$cachedZip.partial"
        Invoke-WebRequest -Uri $wrapperUrl -OutFile $partialZip
        Move-Item -LiteralPath $partialZip -Destination $cachedZip -Force
    }
    Expand-Archive -LiteralPath $cachedZip -DestinationPath $cacheDir -Force
}
if (-not (Test-Path -LiteralPath $gradleExecutable)) {
    throw "Gradle executable missing after extraction: $gradleExecutable"
}
if (-not $isWindowsHost) {
    & chmod +x $gradleExecutable
    if ($LASTEXITCODE -ne 0) { throw 'Could not make Gradle executable.' }
}
Write-Host "Using Gradle distribution: $cachedDistribution" -ForegroundColor DarkGray

Write-ProjectFile "app/build.gradle" @"
plugins {
    id 'com.android.application'
    id 'org.jetbrains.kotlin.android'
    id 'org.jetbrains.kotlin.plugin.compose'
    id 'com.google.dagger.hilt.android'
    id 'com.google.devtools.ksp'
    id 'org.jlleitschuh.gradle.ktlint'
}

kotlin {
    jvmToolchain(17)
}

android {
    namespace '$PackageName'
    compileSdk 35

    compileOptions {
        sourceCompatibility JavaVersion.VERSION_17
        targetCompatibility JavaVersion.VERSION_17
    }

    buildFeatures { compose true }

    defaultConfig {
        applicationId '$PackageName'
        minSdk 23
        targetSdk 35
        versionCode 1
        versionName '1.0'
    }
}

dependencies {
    implementation platform('androidx.compose:compose-bom:2024.12.01')
    implementation 'androidx.activity:activity-compose:1.10.0'
    implementation 'androidx.lifecycle:lifecycle-viewmodel-compose:2.8.7'
    implementation 'androidx.compose.ui:ui'
    implementation 'androidx.compose.ui:ui-tooling-preview'
    implementation 'androidx.compose.material3:material3'
    debugImplementation 'androidx.compose.ui:ui-tooling'
    implementation 'androidx.hilt:hilt-navigation-compose:1.2.0'
    implementation 'com.google.dagger:hilt-android:2.51.1'
    ksp 'com.google.dagger:hilt-compiler:2.51.1'
}
"@

Write-ProjectFile "app/src/main/AndroidManifest.xml" @"
<manifest xmlns:android="http://schemas.android.com/apk/res/android">
    <application
        android:name=".$($ProjectName.Replace(' ', ''))App"
        android:theme="@android:style/Theme.Material.Light.NoActionBar"
        android:label="$ProjectName">
        <activity android:name=".$(($PackageName -split '\.')[-1] -replace '^(.)(.*)$', '$1$2')MainActivity" android:exported="true">
            <intent-filter>
                <action android:name="android.intent.action.MAIN" />
                <category android:name="android.intent.category.LAUNCHER" />
            </intent-filter>
        </activity>
    </application>
</manifest>
"@

# Android activity names are package-independent; use the generated MainActivity explicitly.
$manifestPath = Join-Path $projectDir "app/src/main/AndroidManifest.xml"
(Get-Content -Raw $manifestPath).Replace(".$(($PackageName -split '\.')[-1] -replace '^(.)(.*)$', '$1$2')MainActivity", ".MainActivity") |
    ForEach-Object { [System.IO.File]::WriteAllText($manifestPath, $_, (New-Object System.Text.UTF8Encoding($false))) }

Write-ProjectFile "app/src/main/java/$packagePath/MainActivity.kt" @"
package $PackageName

import android.os.Bundle
import androidx.activity.ComponentActivity
import androidx.activity.compose.setContent
import androidx.activity.viewModels
import androidx.compose.foundation.layout.Arrangement
import androidx.compose.foundation.layout.Column
import androidx.compose.foundation.layout.fillMaxSize
import androidx.compose.material3.MaterialTheme
import androidx.compose.material3.Surface
import androidx.compose.material3.Text
import androidx.compose.runtime.Composable
import androidx.compose.ui.Alignment
import androidx.compose.ui.Modifier
import dagger.hilt.android.AndroidEntryPoint

@AndroidEntryPoint
class MainActivity : ComponentActivity() {
    private val viewModel: SimpleAndroidViewModel by viewModels()

    override fun onCreate(savedInstanceState: Bundle?) {
        super.onCreate(savedInstanceState)
        setContent {
            MaterialTheme {
                Surface(modifier = Modifier.fillMaxSize()) {
                    greeting(viewModel.uiState.value)
                }
            }
        }
    }
}

@Composable
private fun greeting(message: String) {
    Column(
        modifier = Modifier.fillMaxSize(),
        horizontalAlignment = Alignment.CenterHorizontally,
        verticalArrangement = Arrangement.Center
    ) {
        Text(message)
    }
}
"@

Write-ProjectFile "app/src/main/java/$packagePath/data/HomeDataSource.kt" @"
package $PackageName.data

import javax.inject.Inject

class HomeDataSource @Inject constructor() {
    fun getGreeting(): String = "Hello, Jetpack Compose!"
}
"@

Write-ProjectFile "app/src/main/java/$packagePath/data/HomeRepository.kt" @"
package $PackageName.data

import javax.inject.Inject

class HomeRepository @Inject constructor(
    private val dataSource: HomeDataSource
) {
    fun getGreeting(): String = dataSource.getGreeting()
}
"@

Write-ProjectFile "app/src/main/java/$packagePath/SimpleAndroidViewModel.kt" @"
package $PackageName

import androidx.lifecycle.ViewModel
import dagger.hilt.android.lifecycle.HiltViewModel
import javax.inject.Inject
import $PackageName.data.HomeRepository
import kotlinx.coroutines.flow.MutableStateFlow
import kotlinx.coroutines.flow.StateFlow
import kotlinx.coroutines.flow.asStateFlow

@HiltViewModel
class SimpleAndroidViewModel @Inject constructor(
    repository: HomeRepository
) : ViewModel() {
    private val _uiState = MutableStateFlow(repository.getGreeting())
    val uiState: StateFlow<String> = _uiState.asStateFlow()
}
"@

Write-ProjectFile "app/src/main/java/$packagePath/$($ProjectName.Replace(' ', ''))App.kt" @"
package $PackageName

import android.app.Application
import dagger.hilt.android.HiltAndroidApp

@HiltAndroidApp
class $($ProjectName.Replace(' ', ''))App : Application()
"@

Write-ProjectFile "README.md" @"
# $ProjectName

Minimal Kotlin + Jetpack Compose Android starter generated by `init-simple-android-2.ps1`.

Open this folder in Android Studio, let Gradle sync, and run the `app` configuration.
"@

Write-Host "Created Android starter at: $projectDir" -ForegroundColor Green
Write-Host "Next: open '$projectDir' in Android Studio and run the app."

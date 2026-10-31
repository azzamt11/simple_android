param(
    [string]$ProjectName = "SimpleAndroid",
    [string]$PackageName = "com.example.simpleandroid",
    [string]$OutputPath = (Get-Location).Path,
    [string]$GradleVersion = "8.11.1",
    [switch]$Force
)

$ErrorActionPreference = "Stop"

function Find-Jdk17 {
    $candidates = @()
    if ($env:JAVA_HOME) { $candidates += $env:JAVA_HOME }
    $candidates += @(Get-ChildItem "C:\Program Files\Microsoft\jdk-17*" -Directory -ErrorAction SilentlyContinue | Select-Object -ExpandProperty FullName)
    $candidates += @(Get-ChildItem "C:\Program Files\Java\jdk-17*" -Directory -ErrorAction SilentlyContinue | Select-Object -ExpandProperty FullName)
    $candidates += @(Get-ChildItem "$env:LOCALAPPDATA\Programs\Microsoft\jdk-17*" -Directory -ErrorAction SilentlyContinue | Select-Object -ExpandProperty FullName)

    foreach ($candidate in ($candidates | Select-Object -Unique)) {
        $java = Join-Path $candidate "bin\java.exe"
        if (Test-Path $java) {
            $version = (& cmd.exe /c ('"{0}" -version 2>&1' -f $java) | Out-String)
            if ($version -match 'version "17\.') { return $candidate }
        }
    }
    return $null
}

$jdk17 = Find-Jdk17
if (-not $jdk17) {
    if (-not (Get-Command winget -ErrorAction SilentlyContinue)) {
        throw "JDK 17 is required, but neither JDK 17 nor Windows Package Manager (winget) was found. Install Microsoft OpenJDK 17 and run this script again."
    }
    Write-Host "JDK 17 not found. Installing Microsoft OpenJDK 17..." -ForegroundColor Yellow
    & winget install --id Microsoft.OpenJDK.17 --exact --scope user --accept-source-agreements --accept-package-agreements
    if ($LASTEXITCODE -ne 0) { throw "JDK 17 installation failed with exit code $LASTEXITCODE." }
    $jdk17 = Find-Jdk17
    if (-not $jdk17) { throw "JDK 17 was installed, but it was not detected. Restart PowerShell and run this script again." }
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
@rem Gradle startup script for Windows
@if "%DEBUG%"=="" @echo off
set DIRNAME=%~dp0
if "%DIRNAME%"=="" set DIRNAME=.
set APP_BASE_NAME=%~n0
set APP_HOME=%DIRNAME%

@rem Resolve java.exe
set "JAVA_HOME=$jdk17"
set "JAVA_EXE=%JAVA_HOME%\bin\java.exe"
set "GRADLE_USER_HOME=%APP_HOME%..\.gradle-user-home"

set GRADLE_HOME=%APP_HOME%..\.gradle-wrapper-cache\8.11.1\gradle-8.11.1
call "%GRADLE_HOME%\bin\gradle.bat" %*
exit /b %ERRORLEVEL%
"@

Write-AsciiProjectFile "gradlew" @'
#!/bin/sh
APP_HOME=$(CDPATH= cd -- "$(dirname -- "$0")" && pwd -P)
exec "$APP_HOME/../.gradle-wrapper-cache/8.11.1/gradle-8.11.1/bin/gradle" "$@"
'@

$wrapperJar = Join-Path $projectDir "gradle/wrapper/gradle-wrapper.jar"
$wrapperUrl = "https://services.gradle.org/distributions/gradle-$GradleVersion-bin.zip"
$cacheDir = Join-Path $OutputPath ".gradle-wrapper-cache\$GradleVersion"
$cachedZip = Join-Path $cacheDir "gradle-$GradleVersion-bin.zip"
$cachedJars = Join-Path $cacheDir "jars"
$cachedDistribution = Join-Path $cacheDir "gradle-$GradleVersion"
try {
    New-Item -ItemType Directory -Force -Path $cacheDir, $cachedJars | Out-Null
    if (-not (Test-Path (Join-Path $cachedDistribution "bin/gradle.bat"))) {
        if (-not (Test-Path $cachedZip)) {
            Invoke-WebRequest -Uri $wrapperUrl -OutFile $cachedZip -UseBasicParsing
        }
        Expand-Archive -LiteralPath $cachedZip -DestinationPath $cacheDir -Force
    }
    $localJars = @(Get-ChildItem -LiteralPath $cachedJars -Filter "gradle-wrapper*.jar" -ErrorAction SilentlyContinue)
    if ($localJars.Count -eq 0) {
        if (-not (Test-Path $cachedZip)) {
            Invoke-WebRequest -Uri $wrapperUrl -OutFile $cachedZip -UseBasicParsing
        }
        $tempDir = Join-Path ([System.IO.Path]::GetTempPath()) "gradle-wrapper-$GradleVersion"
        if (Test-Path $tempDir) { Remove-Item -LiteralPath $tempDir -Recurse -Force }
        Expand-Archive -LiteralPath $cachedZip -DestinationPath $tempDir -Force
        $sourceJars = Get-ChildItem -LiteralPath $tempDir -Recurse -Filter "gradle-wrapper*.jar"
        if ($sourceJars) {
            foreach ($sourceJar in $sourceJars) {
                Copy-Item -LiteralPath $sourceJar.FullName -Destination (Join-Path $cachedJars $sourceJar.Name) -Force
            }
        }
        Remove-Item -LiteralPath $tempDir -Recurse -Force
    }
    $sourceJars = Get-ChildItem -LiteralPath $cachedJars -Filter "gradle-wrapper*.jar"
    if (-not $sourceJars) { throw "Gradle distribution did not contain wrapper JARs." }
    Get-ChildItem -LiteralPath (Split-Path $wrapperJar -Parent) -Filter "gradle-wrapper*.jar" |
        Remove-Item -Force
    foreach ($sourceJar in $sourceJars) {
        Copy-Item -LiteralPath $sourceJar.FullName -Destination (Join-Path (Split-Path $wrapperJar -Parent) $sourceJar.Name) -Force
    }
    Write-Host "Reused Gradle wrapper cache: $cacheDir" -ForegroundColor DarkGray
} catch {
    if (Test-Path $wrapperJar) { Remove-Item -LiteralPath $wrapperJar -Force }
    Write-Warning "Could not download the Gradle wrapper JAR. Run this script again with internet access. URL: $wrapperUrl"
}

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

Minimal Kotlin + Jetpack Compose Android starter generated by `init-simple-android.ps1`.

Open this folder in Android Studio, let Gradle sync, and run the `app` configuration.
"@

Write-Host "Created Android starter at: $projectDir" -ForegroundColor Green
Write-Host "Next: open '$projectDir' in Android Studio and run the app."

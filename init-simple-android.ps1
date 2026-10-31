param(
    [string]$ProjectName = "SimpleAndroid",
    [string]$PackageName = "com.example.simpleandroid",
    [string]$OutputPath = (Get-Location).Path,
    [string]$GradleVersion = "8.11.1",
    [switch]$Force
)

$ErrorActionPreference = "Stop"

if ($PackageName -notmatch '^[A-Za-z_][A-Za-z0-9_]*(\.[A-Za-z_][A-Za-z0-9_]*)+$') {
    throw "PackageName must look like com.example.app"
}

$projectDir = Join-Path $OutputPath $ProjectName
if ((Test-Path $projectDir) -and -not $Force) {
    throw "Target directory already exists: $projectDir. Use -Force to overwrite generated files."
}

New-Item -ItemType Directory -Force -Path `
    (Join-Path $projectDir "app/src/main/java/$($PackageName.Replace('.', '/'))"), `
    (Join-Path $projectDir "app/src/main/res/layout"), `
    (Join-Path $projectDir "app/src/main/res/values") | Out-Null

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
}
"@

Write-ProjectFile "gradle.properties" @"
org.gradle.jvmargs=-Xmx2048m -Dfile.encoding=UTF-8
android.useAndroidX=true
android.nonTransitiveRClass=true
"@

Write-ProjectFile "gradle/wrapper/gradle-wrapper.properties" @"
distributionBase=GRADLE_USER_HOME
distributionPath=wrapper/dists
distributionUrl=https\://services.gradle.org/distributions/gradle-$GradleVersion-bin.zip
networkTimeout=10000
zipStoreBase=GRADLE_USER_HOME
zipStorePath=wrapper/dists
"@

Write-AsciiProjectFile "gradlew.bat" @'
@rem Gradle startup script for Windows
@if "%DEBUG%"=="" @echo off
set DIRNAME=%~dp0
if "%DIRNAME%"=="" set DIRNAME=.
set APP_BASE_NAME=%~n0
set APP_HOME=%DIRNAME%

@rem Resolve java.exe
if defined JAVA_HOME set JAVA_EXE=%JAVA_HOME%\bin\java.exe
if not defined JAVA_HOME set JAVA_EXE=java.exe

set GRADLE_HOME=%APP_HOME%..\.gradle-wrapper-cache\8.11.1\gradle-8.11.1
call "%GRADLE_HOME%\bin\gradle.bat" %*
exit /b %ERRORLEVEL%
'@

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
plugins { id 'com.android.application' }

android {
    namespace '$PackageName'
    compileSdk 35

    compileOptions {
        sourceCompatibility JavaVersion.VERSION_17
        targetCompatibility JavaVersion.VERSION_17
    }

    defaultConfig {
        applicationId '$PackageName'
        minSdk 23
        targetSdk 35
        versionCode 1
        versionName '1.0'
    }
}

dependencies {
    implementation 'androidx.appcompat:appcompat:1.7.0'
    implementation 'com.google.android.material:material:1.12.0'
}
"@

Write-ProjectFile "app/src/main/AndroidManifest.xml" @"
<manifest xmlns:android="http://schemas.android.com/apk/res/android">
    <application
        android:theme="@style/Theme.SimpleAndroid"
        android:label="@string/app_name">
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

Write-ProjectFile "app/src/main/res/values/strings.xml" @"
<resources>
    <string name="app_name">$ProjectName</string>
</resources>
"@

Write-ProjectFile "app/src/main/res/values/themes.xml" @"
<resources>
    <style name="Theme.SimpleAndroid" parent="Theme.Material3.DayNight.NoActionBar" />
</resources>
"@

Write-ProjectFile "app/src/main/res/layout/activity_main.xml" @"
<?xml version="1.0" encoding="utf-8"?>
<LinearLayout xmlns:android="http://schemas.android.com/apk/res/android"
    android:layout_width="match_parent"
    android:layout_height="match_parent"
    android:gravity="center"
    android:orientation="vertical"
    android:padding="24dp">

    <TextView
        android:layout_width="wrap_content"
        android:layout_height="wrap_content"
        android:text="Hello, Android!"
        android:textSize="24sp" />
</LinearLayout>
"@

Write-ProjectFile "app/src/main/java/$packagePath/MainActivity.java" @"
package $PackageName;

import android.os.Bundle;
import androidx.appcompat.app.AppCompatActivity;

public class MainActivity extends AppCompatActivity {
    @Override
    protected void onCreate(Bundle savedInstanceState) {
        super.onCreate(savedInstanceState);
        setContentView(R.layout.activity_main);
    }
}
"@

Write-ProjectFile "README.md" @"
# $ProjectName

Minimal Java-native Android starter generated by `init-simple-android.ps1`.

Open this folder in Android Studio, let Gradle sync, and run the `app` configuration.
"@

Write-Host "Created Android starter at: $projectDir" -ForegroundColor Green
Write-Host "Next: open '$projectDir' in Android Studio and run the app."

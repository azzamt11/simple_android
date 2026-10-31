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
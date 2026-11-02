@echo off
set "JAVA_HOME=/usr/lib/jvm/java-1.17.0-openjdk-amd64"
set "GRADLE_USER_HOME=%~dp0..\.gradle-user-home"
call "%~dp0..\.gradle-wrapper-cache\8.11.1\gradle-8.11.1\bin\gradle.bat" %*
exit /b %ERRORLEVEL%
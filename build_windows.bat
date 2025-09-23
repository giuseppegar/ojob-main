@echo off
echo ==========================================
echo  Job Schedule Generator - Windows Build
echo ==========================================
echo.

echo [1/6] Checking Flutter installation...
flutter --version
if errorlevel 1 (
    echo ERROR: Flutter not found! Please install Flutter first.
    pause
    exit /b 1
)

echo.
echo [2/6] Enabling Windows desktop...
flutter config --enable-windows-desktop
flutter config --no-analytics

echo.
echo [3/6] Getting dependencies...
flutter pub get
if errorlevel 1 (
    echo ERROR: Failed to get dependencies!
    pause
    exit /b 1
)

echo.
echo [4/6] Analyzing code...
flutter analyze
if errorlevel 1 (
    echo WARNING: Code analysis found issues, but continuing...
)

echo.
echo [5/6] Building Windows app...
flutter build windows --release --verbose
if errorlevel 1 (
    echo ERROR: Build failed!
    pause
    exit /b 1
)

echo.
echo [6/6] Creating installer package...
powershell -ExecutionPolicy Bypass -File "create_installer.ps1"

echo.
echo ==========================================
echo  Build completed successfully!
echo ==========================================
echo.
echo Your installer is ready in the 'dist' folder:
dir dist\JobScheduleGenerator-Windows-*.zip 2>nul
echo.
pause
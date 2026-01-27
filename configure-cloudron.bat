@echo off
setlocal enabledelayedexpansion

:: One-time Cloudron App Configuration Script
:: This points your existing Mattermost app to use your custom Docker Hub builds

echo.
echo ================================================================================
echo Configure Cloudron App - One-Time Setup
echo ================================================================================
echo.
echo This script will configure your existing Mattermost app to use builds from
echo your Docker Hub repository instead of the official App Store.
echo.
echo IMPORTANT: Run this ONCE after Docker Hub setup, before your first deployment.
echo.
echo ================================================================================
echo.

:: Check if cloudron CLI is installed
echo Checking for Cloudron CLI...
where cloudron >nul 2>&1
if errorlevel 1 (
    echo.
    echo ERROR: Cloudron CLI is not installed or not in PATH
    echo.
    echo Install it with: npm install -g cloudron
    echo Or see: https://docs.cloudron.io/packaging/cli/
    echo.
    exit /b 1
)

echo Cloudron CLI found: OK
echo.

:: Check if logged in to Cloudron
cloudron list >nul 2>&1
if errorlevel 1 (
    echo.
    echo ERROR: Not logged in to Cloudron
    echo.
    echo Please login first with: cloudron login
    echo.
    exit /b 1
)

:: Check if docker is logged in
docker info >nul 2>&1
if errorlevel 1 (
    echo.
    echo ERROR: Docker is not running or not logged in
    echo.
    echo Please run: docker login
    echo.
    exit /b 1
)

echo Docker login: OK
echo.

:: Show list of apps
echo Your Cloudron apps:
echo.
cloudron list
echo.
echo ================================================================================
echo.

:: Prompt for app selection
set /p APP_SELECTION="Enter the app ID or location of your Mattermost app: "

if "%APP_SELECTION%"=="" (
    echo Error: No app selected
    exit /b 1
)

echo.
echo Selected app: %APP_SELECTION%
echo.

:: Get Docker Hub username
set /p DOCKER_USERNAME="Enter your Docker Hub username: "

if "%DOCKER_USERNAME%"=="" (
    echo Error: No username entered
    exit /b 1
)

set DOCKER_IMAGE=%DOCKER_USERNAME%/mattermost-extended-cloudron

echo.
echo ================================================================================
echo Configuration Summary
echo ================================================================================
echo.
echo App: %APP_SELECTION%
echo Docker Hub Image: %DOCKER_IMAGE%
echo.
echo This will configure Cloudron to pull updates from your Docker Hub repository.
echo After this, when you run deploy.bat and push to Docker Hub, the UPDATE button
echo will appear in Cloudron UI automatically!
echo.
echo ================================================================================
echo.

set /p CONFIRM="Proceed with configuration? (Y/N): "

if /i not "%CONFIRM%"=="Y" (
    echo Configuration cancelled.
    exit /b 0
)

echo.
echo ================================================================================
echo Building and Pushing Initial Image
echo ================================================================================
echo.
echo This will build your current Dockerfile and push to Docker Hub...
echo.

:: Configure cloudron build with the repository
echo Configuring cloudron build...
echo %DOCKER_IMAGE% > .cloudron_repo_temp.txt
cloudron build --set-repository %DOCKER_IMAGE%
if errorlevel 1 (
    del .cloudron_repo_temp.txt >nul 2>&1
    echo.
    echo ERROR: Failed to configure repository
    exit /b 1
)
del .cloudron_repo_temp.txt >nul 2>&1

:: Build and push
echo.
echo Building Docker image...
cloudron build
if errorlevel 1 (
    echo.
    echo ERROR: Build failed
    echo.
    echo Make sure:
    echo 1. Docker is running
    echo 2. You're logged into Docker Hub: docker login
    echo 3. Dockerfile is valid
    exit /b 1
)

echo.
echo ================================================================================
echo Installing Custom Build to Cloudron
echo ================================================================================
echo.

:: Install the custom build
cloudron install --app %APP_SELECTION%
if errorlevel 1 (
    echo.
    echo ERROR: Installation failed
    echo.
    echo The app may still be running on the old version.
    echo Check Cloudron logs for details.
    exit /b 1
)

echo.
echo ================================================================================
echo SUCCESS! Configuration Complete
echo ================================================================================
echo.
echo Your Mattermost app is now configured to use your custom Docker Hub builds!
echo.
echo What happens next:
echo 1. When you run deploy.bat, it builds and pushes to Docker Hub
echo 2. Cloudron detects the new version
echo 3. The UPDATE button appears in Cloudron UI
echo 4. Click UPDATE to deploy!
echo.
echo Your Docker Hub repository: https://hub.docker.com/r/%DOCKER_IMAGE%
echo.
echo ================================================================================

endlocal

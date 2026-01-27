@echo off
setlocal enabledelayedexpansion

:: Mattermost Cloudron App Deploy Script
:: Usage: deploy.bat <custom-version>
:: Example: deploy.bat 9.11.0-custom.1

if "%~1"=="" (
    echo Usage: deploy.bat ^<custom-version^>
    echo Example: deploy.bat 9.11.0-custom.1
    exit /b 1
)

set CUSTOM_VERSION=%~1

:: Remove v prefix if present
set CUSTOM_VERSION=%CUSTOM_VERSION:v=%

echo.
echo ================================================================================
echo Mattermost Custom Build - Cloudron Deployment
echo ================================================================================
echo Custom Build Version: %CUSTOM_VERSION%
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

:: Check if cloudron build is configured
if not exist "%USERPROFILE%\.cloudron.json" (
    echo.
    echo ERROR: Cloudron build not configured yet
    echo.
    echo Please run configure-cloudron.bat first to set up Docker Hub integration.
    echo.
    exit /b 1
)

echo Cloudron build configured: OK
echo.

echo ================================================================================
echo Updating Dockerfile
echo ================================================================================
echo.

:: Backup Dockerfile
copy Dockerfile Dockerfile.bak >nul

:: Update Dockerfile MM_VERSION
echo Updating MM_VERSION to %CUSTOM_VERSION%...
powershell -Command "(Get-Content Dockerfile) -replace 'ARG MM_VERSION=.*', 'ARG MM_VERSION=%CUSTOM_VERSION%' | Set-Content Dockerfile"
if errorlevel 1 (
    echo Error: Failed to update Dockerfile
    move /y Dockerfile.bak Dockerfile >nul
    exit /b 1
)

:: Update Dockerfile download URLs to use custom fork
powershell -Command "(Get-Content Dockerfile) -replace 'https://releases.mattermost.com/\$\{MM_VERSION\}/mattermost-team-\$\{MM_VERSION\}', 'https://github.com/stalecontext/mattermost-extended/releases/download/v${MM_VERSION}/mattermost-team-${MM_VERSION}' | Set-Content Dockerfile"
powershell -Command "(Get-Content Dockerfile) -replace 'https://releases.mattermost.com/\$\{MM_VERSION\}/mattermost-\$\{MM_VERSION\}-linux', 'https://github.com/stalecontext/mattermost-extended/releases/download/v${MM_VERSION}/mattermost-${MM_VERSION}-linux' | Set-Content Dockerfile"

:: Clean up backup
del Dockerfile.bak

:: Show changes
echo.
echo Changes made to Dockerfile:
git diff Dockerfile
echo.

echo ================================================================================
echo Building and Pushing to Docker Hub
echo ================================================================================
echo.
echo This will:
echo 1. Build the Docker image locally
echo 2. Push it to your Docker Hub repository
echo 3. Cloudron will detect the update and show UPDATE button
echo.

:: Build and push
cloudron build
if errorlevel 1 (
    echo.
    echo ERROR: Cloudron build failed
    echo.
    echo Restoring original Dockerfile...
    git checkout Dockerfile
    exit /b 1
)

echo.
echo ================================================================================
echo SUCCESS! Build Pushed to Docker Hub
echo ================================================================================
echo.
echo The new version has been pushed to Docker Hub.
echo.
echo Next steps:
echo 1. Go to your Cloudron dashboard
echo 2. Wait 1-2 minutes for Cloudron to detect the update
echo 3. Click the UPDATE button when it appears
echo 4. Monitor logs during update
echo.
echo To commit Dockerfile changes:
echo   git add Dockerfile
echo   git commit -m "Update to %CUSTOM_VERSION%"
echo   git push
echo.
echo To revert Dockerfile changes:
echo   git checkout Dockerfile
echo.
echo ================================================================================

endlocal

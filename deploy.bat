@echo off
setlocal enabledelayedexpansion

:: Mattermost Cloudron App Deploy Script
:: Usage: deploy.bat <custom-version> [cloudron-revision]
:: Example: deploy.bat 9.11.0-custom.1
:: Example: deploy.bat 9.11.0-custom.1 2

if "%~1"=="" (
    echo Usage: deploy.bat ^<custom-version^> [cloudron-revision]
    echo Example: deploy.bat 9.11.0-custom.1
    echo Example: deploy.bat 9.11.0-custom.1 2
    exit /b 1
)

set CUSTOM_VERSION=%~1
set CLOUDRON_REV=%~2

:: Remove v prefix if present
set CUSTOM_VERSION=%CUSTOM_VERSION:v=%

:: Extract base version (9.11.0 from 9.11.0-custom.1)
for /f "tokens=1 delims=-" %%a in ("%CUSTOM_VERSION%") do set BASE_VERSION=%%a

:: Default to revision 1 if not specified
if "%CLOUDRON_REV%"=="" set CLOUDRON_REV=1

set CLOUDRON_VERSION=%BASE_VERSION%-%CLOUDRON_REV%

echo.
echo ================================================================================
echo Deploying Mattermost Custom Build
echo ================================================================================
echo Custom Build Version: %CUSTOM_VERSION%
echo Cloudron App Version: %CLOUDRON_VERSION%
echo ================================================================================
echo.

:: Check if on main branch
git branch --show-current | findstr "main" >nul
if errorlevel 1 (
    echo Warning: Not on main branch. Continue? (Y/N)
    set /p CONTINUE=
    if /i not "!CONTINUE!"=="Y" exit /b 1
)

:: Backup Dockerfile
copy Dockerfile Dockerfile.bak >nul

:: Update Dockerfile MM_VERSION
echo Updating Dockerfile...
powershell -Command "(Get-Content Dockerfile) -replace 'ARG MM_VERSION=.*', 'ARG MM_VERSION=%CUSTOM_VERSION%' | Set-Content Dockerfile"
if errorlevel 1 (
    echo Error: Failed to update Dockerfile
    move /y Dockerfile.bak Dockerfile >nul
    exit /b 1
)

:: Update Dockerfile download URL to use custom fork
powershell -Command "(Get-Content Dockerfile) -replace 'curl -L https://releases.mattermost.com/\$\{MM_VERSION\}/mattermost-team-\$\{MM_VERSION\}-linux-amd64.tar.gz', 'curl -L https://github.com/stalecontext/mattermost/releases/download/v${MM_VERSION}/mattermost-team-${MM_VERSION}-linux-amd64.tar.gz' | Set-Content Dockerfile"
powershell -Command "(Get-Content Dockerfile) -replace 'curl -L https://releases.mattermost.com/\$\{MM_VERSION\}/mattermost-\$\{MM_VERSION\}-linux-amd64.tar.gz', 'curl -L https://github.com/stalecontext/mattermost/releases/download/v${MM_VERSION}/mattermost-${MM_VERSION}-linux-amd64.tar.gz' | Set-Content Dockerfile"

:: Backup CloudronManifest.json
copy CloudronManifest.json CloudronManifest.json.bak >nul

:: Update CloudronManifest.json
echo Updating CloudronManifest.json...
powershell -Command "$json = Get-Content CloudronManifest.json | ConvertFrom-Json; $json.version = '%CLOUDRON_VERSION%'; $json.upstreamVersion = '%CUSTOM_VERSION%'; $json | ConvertTo-Json -Depth 10 | Set-Content CloudronManifest.json"
if errorlevel 1 (
    echo Error: Failed to update CloudronManifest.json
    move /y Dockerfile.bak Dockerfile >nul
    move /y CloudronManifest.json.bak CloudronManifest.json >nul
    exit /b 1
)

:: Clean up backups
del Dockerfile.bak CloudronManifest.json.bak

:: Show changes
echo.
echo Changes to commit:
git diff Dockerfile CloudronManifest.json

echo.
echo Commit and push these changes? (Y/N)
set /p CONFIRM=
if /i not "%CONFIRM%"=="Y" (
    echo Deployment cancelled. Changes preserved.
    exit /b 0
)

:: Commit and push
echo.
echo Committing changes...
git add Dockerfile CloudronManifest.json
git commit -m "Deploy custom build v%CUSTOM_VERSION% (Cloudron v%CLOUDRON_VERSION%)"
if errorlevel 1 (
    echo Error: Commit failed
    exit /b 1
)

echo.
echo Pushing to GitHub...
git push
if errorlevel 1 (
    echo Error: Push failed
    exit /b 1
)

echo.
echo ================================================================================
echo SUCCESS! Deployment committed and pushed
echo ================================================================================
echo.
echo Next steps:
echo 1. Wait a few minutes for Cloudron to detect the update
echo 2. Go to your Cloudron dashboard
echo 3. Click the UPDATE button when it appears
echo 4. Monitor logs during update
echo.
echo To rollback if needed:
echo   git revert HEAD
echo   git push
echo.
echo ================================================================================

endlocal

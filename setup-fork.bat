@echo off
setlocal

:: One-time setup script for Mattermost Cloudron App fork
:: This configures git remotes to use your fork

echo.
echo ================================================================================
echo Mattermost Cloudron App Fork - One-Time Setup
echo ================================================================================
echo.

:: Check if already configured
git remote -v | findstr "stalecontext/mattermost-extended-cloudron-app" >nul
if not errorlevel 1 (
    echo This repository is already configured for stalecontext/mattermost-extended-cloudron-app
    echo.
    git remote -v
    echo.
    exit /b 0
)

echo This will:
echo 1. Create a fork of the Cloudron Mattermost app on GitHub
echo 2. Update your local repository to point to your fork
echo 3. Add upstream remote for syncing with official Cloudron releases
echo.
echo IMPORTANT: Before running this script:
echo 1. Go to https://git.cloudron.io/cloudron/mattermost-app
echo 2. Copy the repository (or create a new repo on GitHub)
echo 3. Create a new repository: https://github.com/stalecontext/mattermost-extended-cloudron-app
echo 4. You can push the current code to initialize it
echo.
set /p CREATED="Have you created stalecontext/mattermost-extended-cloudron-app? (Y/N): "
if /i not "%CREATED%"=="Y" (
    echo Please create the repository first, then run this script again.
    exit /b 1
)

echo.
echo Configuring remotes...

:: Rename current origin to upstream
git remote rename origin upstream
if errorlevel 1 (
    echo Note: Could not rename origin (may not exist)
)

:: Add your fork as origin
git remote add origin https://github.com/stalecontext/mattermost-extended-cloudron-app.git
if errorlevel 1 (
    echo Error: Failed to add origin remote
    exit /b 1
)

:: Verify upstream exists
git remote | findstr "upstream" >nul
if errorlevel 1 (
    echo Adding upstream remote...
    git remote add upstream https://git.cloudron.io/cloudron/mattermost-app.git
)

:: Show remotes
echo.
echo Configured remotes:
git remote -v

:: Push to your fork
echo.
echo Pushing to your fork...
git push -u origin main
if errorlevel 1 (
    echo Note: Push may have failed. You might need to:
    echo   git push -u origin main --force
    echo if the remote repository is empty.
)

echo.
echo ================================================================================
echo SUCCESS! Repository configured
echo ================================================================================
echo.
echo Remotes:
echo   origin   = stalecontext/mattermost-extended-cloudron-app (your fork)
echo   upstream = cloudron/mattermost-app (official)
echo.
echo Next steps:
echo 1. After building your custom Mattermost release
echo 2. Run: .\deploy.bat 9.11.0-custom.1
echo.
echo ================================================================================

endlocal

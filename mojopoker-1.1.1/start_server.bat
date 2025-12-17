@echo off
REM Start Mojo Poker Server on Windows
REM Run this from the mojopoker-1.1.1 directory

echo Starting Mojo Poker...
echo.

REM Check for environment variables
if "%FACEBOOK_APP_ID%"=="" (
    echo WARNING: FACEBOOK_APP_ID not set. Facebook login will not work.
)
if "%FACEBOOK_APP_SECRET%"=="" (
    echo WARNING: FACEBOOK_APP_SECRET not set. Facebook login will not work.
)

cd /d "%~dp0"
perl script\mojopoker_win.pl

@echo off
REM Windows Installation Script for Mojo Poker
REM Run this from the mojopoker-1.1.1 directory

echo ================================================
echo   Mojo Poker Windows Installation
echo ================================================
echo.

REM Check if Strawberry Perl is installed
where perl >nul 2>nul
if %ERRORLEVEL% NEQ 0 (
    echo ERROR: Perl not found in PATH
    echo Please install Strawberry Perl from https://strawberryperl.com/
    pause
    exit /b 1
)

echo [1/4] Perl found. Installing CPAN modules...
echo This may take several minutes...
echo.

cpanm Mojolicious DBI DBD::SQLite Moo Tie::IxHash List::AllUtils Algorithm::Combinatorics Digest::SHA SQL::Abstract Data::Dumper Getopt::Long

echo.
echo [2/4] Skipping optional Poker modules...
echo (Poker::Eval and Poker::Robot are optional - the app has built-in evaluators)

echo.
echo [3/4] Initializing databases...
cd db

REM Find sqlite3 - try PATH first, then Strawberry location
where sqlite3 >nul 2>nul
if %ERRORLEVEL% EQU 0 (
    sqlite3 fb.db < fb.schema
    sqlite3 poker.db < poker.schema
) else (
    if exist "C:\Strawberry\c\bin\sqlite3.exe" (
        C:\Strawberry\c\bin\sqlite3.exe fb.db < fb.schema
        C:\Strawberry\c\bin\sqlite3.exe poker.db < poker.schema
    ) else (
        echo WARNING: sqlite3 not found. Please initialize databases manually.
    )
)

cd ..

echo.
echo [4/4] Installation complete!
echo.
echo ================================================
echo   Next Steps:
echo ================================================
echo.
echo 1. Set environment variables:
echo    set FACEBOOK_APP_ID=your_app_id
echo    set FACEBOOK_APP_SECRET=your_app_secret
echo.
echo 2. Start the server:
echo    perl script\mojopoker_win.pl
echo.
echo 3. Open browser to http://localhost:3000
echo.
echo ================================================
pause

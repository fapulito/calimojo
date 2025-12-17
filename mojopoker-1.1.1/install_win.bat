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

REM Check if cpanm is installed
where cpanm >nul 2>nul
if %ERRORLEVEL% NEQ 0 (
    echo ERROR: cpanm not found in PATH
    echo Please install cpanm first. Run:
    echo   cpan App::cpanminus
    echo Or download from https://cpanmin.us/
    pause
    exit /b 1
)

echo [1/4] Perl and cpanm found. Installing CPAN modules...
echo This may take several minutes...
echo.

cpanm Mojolicious DBI DBD::SQLite Moo Tie::IxHash List::AllUtils Algorithm::Combinatorics Digest::SHA SQL::Abstract Data::Dumper Getopt::Long
if %ERRORLEVEL% NEQ 0 (
    echo.
    echo ERROR: CPAN module installation failed!
    echo Please check the error messages above and try again.
    echo You may need to run this script as Administrator.
    pause
    exit /b 1
)

echo.
echo [2/4] Skipping optional Poker modules...
echo (Poker::Eval and Poker::Robot are optional - the app has built-in evaluators)

echo.
echo [3/4] Initializing databases...

REM Verify db directory exists
if not exist "db" (
    echo ERROR: db directory not found!
    echo Please run this script from the mojopoker-1.1.1 directory.
    pause
    exit /b 1
)

pushd db

REM Verify schema files exist
if not exist "fb.schema" (
    echo ERROR: fb.schema not found in db directory!
    echo The installation files may be incomplete.
    popd
    pause
    exit /b 1
)

if not exist "poker.schema" (
    echo ERROR: poker.schema not found in db directory!
    echo The installation files may be incomplete.
    popd
    pause
    exit /b 1
)

REM Find sqlite3 - try PATH first, then Strawberry location
set SQLITE3_CMD=
where sqlite3 >nul 2>nul
if %ERRORLEVEL% EQU 0 (
    set SQLITE3_CMD=sqlite3
) else (
    if exist "C:\Strawberry\c\bin\sqlite3.exe" (
        set SQLITE3_CMD=C:\Strawberry\c\bin\sqlite3.exe
    ) else (
        echo ERROR: sqlite3 not found!
        echo Please ensure sqlite3 is in PATH or Strawberry Perl is installed.
        popd
        pause
        exit /b 1
    )
)

echo Creating fb.db...
%SQLITE3_CMD% fb.db < fb.schema
if %ERRORLEVEL% NEQ 0 (
    echo ERROR: Failed to initialize fb.db!
    echo Check that fb.schema is valid and you have write permissions.
    popd
    pause
    exit /b 1
)

echo Creating poker.db...
%SQLITE3_CMD% poker.db < poker.schema
if %ERRORLEVEL% NEQ 0 (
    echo ERROR: Failed to initialize poker.db!
    echo Check that poker.schema is valid and you have write permissions.
    popd
    pause
    exit /b 1
)

echo Databases initialized successfully.
popd

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

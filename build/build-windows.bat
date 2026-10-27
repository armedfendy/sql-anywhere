@echo off
rem Builds php_sqlanywhere.dll (NTS and TS) for Windows x64 or x86.
rem usage: build\build-windows.bat <php-version> [msvc-version] [x64|x86]
rem   e.g. build\build-windows.bat 8.5.12-1 14.44 x64
rem        build\build-windows.bat 8.5.12-1 14.44 x86
rem Requirements:
rem   - VS Build Tools with the MSVC toolset PHP was linked with
rem     (PHP 8.5 = 14.44: component Microsoft.VisualStudio.Component.VC.14.44.17.14.x86.x64)
rem   - Windows 10/11 SDK
rem PHP refuses to load an extension linked with a newer MSVC than the core,
rem so the toolset must not be newer than the one PHP was built with.
rem Output (same layout as the SAP distribution):
rem   dist\php-<major.minor>\windows\bin64\php-<major.minor>.0_sqlanywhere.dll      (TS; bin32 for x86)
rem   dist\php-<major.minor>\windows\bin64\php-<major.minor>.0_sqlanywhere_nts.dll  (NTS)
rem   packed into dist\php-<major.minor>\SQLAnywhere-php-<major.minor>_Windows.zip
setlocal enabledelayedexpansion
if "%~1"=="" (echo usage: %~nx0 ^<php-version e.g. 8.5.12-1^> [msvc-version] [x64^|x86] & exit /b 1)
set PHPVER=%~1
set MSVC=%~2
if "%MSVC%"=="" set MSVC=14.44
set ARCH=%~3
if "%ARCH%"=="" set ARCH=x64
rem x64 objects land in x64\Release*, x86 objects in Release*
if "%ARCH%"=="x64" (set BIN=bin64& set OBJ=x64\) else if "%ARCH%"=="x86" (set BIN=bin32& set OBJ=) else (echo unknown arch: %ARCH% & exit /b 1)
set CRT=vs17
for /f "tokens=1,2 delims=." %%a in ("%PHPVER%") do set PHPMINOR=%%a.%%b

set SRC=%~dp0..
set WORK=%~dp0work
set OUT=%SRC%\dist\php-%PHPMINOR%\windows\%BIN%
rem Windows' own tar; GNU tar from Git/MSYS treats "C:" as a remote host
set "TAR=%SystemRoot%\System32\tar.exe"
set DL=https://windows.php.net/downloads/releases

rem locate Visual Studio
for /f "usebackq delims=" %%i in (`"%ProgramFiles(x86)%\Microsoft Visual Studio\Installer\vswhere.exe" -latest -products * -property installationPath`) do set VSDIR=%%i
if not defined VSDIR (echo Visual Studio not found & exit /b 1)

rem locate newest Windows SDK (vcvarsall does not always add it)
set KIT=%ProgramFiles(x86)%\Windows Kits\10
for /f "delims=" %%v in ('dir /b /ad /on "%KIT%\Include\10.*"') do set KV=%%v

if not exist "%WORK%" mkdir "%WORK%"
if not exist "%OUT%" mkdir "%OUT%"

rem php-sdk-binary-tools (for the build helpers expected by configure.js)
if not exist "%WORK%\sdk" (
    curl -sfL -o "%WORK%\sdk.zip" https://github.com/php/php-sdk-binary-tools/archive/refs/heads/master.zip || exit /b 1
    "%TAR%" -xf "%WORK%\sdk.zip" -C "%WORK%" || exit /b 1
    ren "%WORK%\php-sdk-binary-tools-master" sdk
)

call "%VSDIR%\VC\Auxiliary\Build\vcvarsall.bat" %ARCH% -vcvars_ver=%MSVC% || exit /b 1
set "PATH=%KIT%\bin\%KV%\x64;%WORK%\sdk\bin;%WORK%\sdk\msys2\usr\bin;%PATH%"
echo %INCLUDE% | find /i "ucrt" >nul || set "INCLUDE=%INCLUDE%;%KIT%\Include\%KV%\ucrt;%KIT%\Include\%KV%\um;%KIT%\Include\%KV%\shared"
echo %LIB% | find /i "ucrt" >nul || set "LIB=%LIB%;%KIT%\Lib\%KV%\ucrt\%ARCH%;%KIT%\Lib\%KV%\um\%ARCH%"

for %%t in (nts ts) do (
    if "%%t"=="nts" (set PFX=nts-& set SFX=_nts& set REL=Release) else (set PFX=& set SFX=& set REL=Release_TS)
    set DEVZIP=php-devel-pack-%PHPVER%-!PFX!Win32-%CRT%-%ARCH%.zip
    if not exist "%WORK%\!DEVZIP!" (
        curl -sfL -o "%WORK%\!DEVZIP!" %DL%/!DEVZIP! || (echo download failed: !DEVZIP! & exit /b 1)
    )
    rmdir /s /q "%WORK%\devel-%ARCH%-%%t" 2>nul
    mkdir "%WORK%\devel-%ARCH%-%%t"
    "%TAR%" -xf "%WORK%\!DEVZIP!" -C "%WORK%\devel-%ARCH%-%%t" || exit /b 1
    for /d %%d in ("%WORK%\devel-%ARCH%-%%t\php-*-devel-*") do set DEVEL=%%d

    rmdir /s /q "%WORK%\b-%ARCH%-%%t" 2>nul
    mkdir "%WORK%\b-%ARCH%-%%t"
    xcopy /q /y "%SRC%\*.c" "%WORK%\b-%ARCH%-%%t\" >nul
    xcopy /q /y "%SRC%\*.h" "%WORK%\b-%ARCH%-%%t\" >nul
    copy /y "%SRC%\config.w32" "%WORK%\b-%ARCH%-%%t\" >nul
    pushd "%WORK%\b-%ARCH%-%%t"
    call "!DEVEL!\phpize.bat" || exit /b 1
    call "%WORK%\b-%ARCH%-%%t\configure.bat" --with-sqlanywhere=shared || exit /b 1
    nmake || exit /b 1
    popd
    copy /y "%WORK%\b-%ARCH%-%%t\%OBJ%!REL!\php_sqlanywhere.dll" "%OUT%\php-%PHPMINOR%.0_sqlanywhere!SFX!.dll" >nul || exit /b 1
    echo built %OUT%\php-%PHPMINOR%.0_sqlanywhere!SFX!.dll
)

rem pack every bin* folder (bin32 too, when present)
pushd "%OUT%\.."
del "..\SQLAnywhere-php-%PHPMINOR%_Windows.zip" 2>nul
"%TAR%" -a -cf "..\SQLAnywhere-php-%PHPMINOR%_Windows.zip" bin* || exit /b 1
popd
echo packed %SRC%\dist\php-%PHPMINOR%\SQLAnywhere-php-%PHPMINOR%_Windows.zip

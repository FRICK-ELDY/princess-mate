@echo off
setlocal

set "SCRIPT_DIR=%~dp0"
set "REPO_ROOT=%SCRIPT_DIR%.."
set "GODOT_PROJECT_DIR=%REPO_ROOT%\godot"
set "BUILD_SCRIPT=%SCRIPT_DIR%build.bat"
set "EXPORT_PRESET=Windows Desktop"
set "EXPORT_PATH=%GODOT_PROJECT_DIR%\build\windows\PrincessMate.exe"
set "NO_EXPORT=0"
set "CLEAN=0"
set "GODOT_EXE="

:parse_args
if "%~1"=="" goto :args_done
if "%~1"=="--godot" (
  if "%~2"=="" (
    echo [ERROR] --godot requires an executable path.
    goto :usage
  )
  set "GODOT_EXE=%~2"
  shift
  shift
  goto :parse_args
)
if "%~1"=="--preset" (
  if "%~2"=="" (
    echo [ERROR] --preset requires a preset name.
    goto :usage
  )
  set "EXPORT_PRESET=%~2"
  shift
  shift
  goto :parse_args
)
if "%~1"=="--output" (
  if "%~2"=="" (
    echo [ERROR] --output requires a target executable path.
    goto :usage
  )
  set "EXPORT_PATH=%~2"
  shift
  shift
  goto :parse_args
)
if "%~1"=="--no-export" (
  set "NO_EXPORT=1"
  shift
  goto :parse_args
)
if "%~1"=="--clean" (
  set "CLEAN=1"
  shift
  goto :parse_args
)
if "%~1"=="-h" goto :usage
if "%~1"=="--help" goto :usage
echo [ERROR] Unknown option: %~1
goto :usage

:args_done
if not exist "%BUILD_SCRIPT%" (
  echo [ERROR] Missing build script: %BUILD_SCRIPT%
  exit /b 1
)

echo [INFO] Step 1/3: Rust debug build
call "%BUILD_SCRIPT%"
if errorlevel 1 (
  echo [ERROR] Debug build failed.
  exit /b 1
)

echo [INFO] Step 2/3: Rust release build
call "%BUILD_SCRIPT%" --release
if errorlevel 1 (
  echo [ERROR] Release build failed.
  exit /b 1
)

if "%NO_EXPORT%"=="1" (
  echo [OK] Release build completed. Export step skipped.
  exit /b 0
)

echo [INFO] Step 3/3: Godot export
if not exist "%GODOT_PROJECT_DIR%\export_presets.cfg" (
  echo [ERROR] export_presets.cfg not found in %GODOT_PROJECT_DIR%
  echo [HINT] Open Godot and create a Windows export preset first.
  echo [HINT] You can rerun with --no-export to only build/copy DLL.
  exit /b 1
)

if "%GODOT_EXE%"=="" (
  if defined GODOT set "GODOT_EXE=%GODOT%"
)
if "%GODOT_EXE%"=="" (
  if defined GODOT4 set "GODOT_EXE=%GODOT4%"
)
if "%GODOT_EXE%"=="" (
  where godot.exe >nul 2>&1 && set "GODOT_EXE=godot.exe"
)
if "%GODOT_EXE%"=="" (
  where godot4.exe >nul 2>&1 && set "GODOT_EXE=godot4.exe"
)
if "%GODOT_EXE%"=="" (
  where godot_console.exe >nul 2>&1 && set "GODOT_EXE=godot_console.exe"
)
if "%GODOT_EXE%"=="" (
  where godot4_console.exe >nul 2>&1 && set "GODOT_EXE=godot4_console.exe"
)
if "%GODOT_EXE%"=="" (
  echo [ERROR] Godot executable was not found.
  echo [HINT] Pass explicit path: --godot "C:\path\to\godot4_console.exe"
  echo [HINT] Or set env var: set GODOT=C:\path\to\godot4_console.exe
  exit /b 1
)
if not "%GODOT_EXE%"=="godot.exe" if not "%GODOT_EXE%"=="godot4.exe" if not "%GODOT_EXE%"=="godot_console.exe" if not "%GODOT_EXE%"=="godot4_console.exe" (
  if not exist "%GODOT_EXE%" (
    echo [ERROR] Specified Godot executable does not exist: %GODOT_EXE%
    exit /b 1
  )
)

for %%I in ("%EXPORT_PATH%") do set "EXPORT_DIR=%%~dpI"
if "%CLEAN%"=="1" (
  if exist "%EXPORT_DIR%" (
    echo [INFO] Cleaning export directory: %EXPORT_DIR%
    rmdir /S /Q "%EXPORT_DIR%"
    if errorlevel 1 (
      echo [ERROR] Could not clean export directory: %EXPORT_DIR%
      exit /b 1
    )
  )
)
if not exist "%EXPORT_DIR%" (
  mkdir "%EXPORT_DIR%" || (
    echo [ERROR] Could not create export directory: %EXPORT_DIR%
    exit /b 1
  )
)

echo [INFO] Export preset: %EXPORT_PRESET%
echo [INFO] Export path: %EXPORT_PATH%
echo [INFO] Godot executable: %GODOT_EXE%
"%GODOT_EXE%" --headless --path "%GODOT_PROJECT_DIR%" --export-release "%EXPORT_PRESET%" "%EXPORT_PATH%"
if errorlevel 1 (
  echo [ERROR] Godot export failed.
  echo [HINT] If this says templates are missing, open Godot and install export templates for your version.
  echo [HINT] Editor menu: Editor -^> Manage Export Templates
  exit /b 1
)

echo [OK] Release export completed: %EXPORT_PATH%
exit /b 0

:usage
echo Usage:
echo   bin\release.bat [--godot "^<path^>"] [--preset "^<name^>"] [--output "^<exe-path^>"] [--clean] [--no-export]
echo.
echo Examples:
echo   bin\release.bat
echo   bin\release.bat --clean
echo   bin\release.bat --no-export
echo   bin\release.bat --godot "C:\Tools\Godot\godot4_console.exe"
echo   bin\release.bat --preset "Windows Desktop" --output "build\windows\PrincessMate.exe"
exit /b 1

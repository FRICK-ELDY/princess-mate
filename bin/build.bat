@echo off
setlocal

set "MODE=debug"
set "CARGO_ARGS="
set "TARGET_DIR_NAME=debug"

if "%~1"=="--release" (
  set "MODE=release"
  set "CARGO_ARGS=--release"
  set "TARGET_DIR_NAME=release"
) else if not "%~1"=="" (
  if "%~1"=="-h" goto :usage
  if "%~1"=="--help" goto :usage
  echo [ERROR] Unknown option: %~1
  goto :usage
)

set "SCRIPT_DIR=%~dp0"
set "REPO_ROOT=%SCRIPT_DIR%.."
set "CRATE_DIR=%REPO_ROOT%\rust\princess-mate-core"
set "SOURCE_DLL=%CRATE_DIR%\target\%TARGET_DIR_NAME%\princess_mate_core.dll"
set "DEST_DIR=%REPO_ROOT%\godot\extension\bin\windows\%TARGET_DIR_NAME%"
set "DEST_DLL=%DEST_DIR%\princess_mate_core.dll"

echo [INFO] Build mode: %MODE%
echo [INFO] Building Rust crate...

pushd "%CRATE_DIR%" >nul || (
  echo [ERROR] Could not access crate directory: %CRATE_DIR%
  exit /b 1
)

cargo build %CARGO_ARGS%
if errorlevel 1 (
  popd >nul
  echo [ERROR] cargo build failed.
  exit /b 1
)

popd >nul

if not exist "%SOURCE_DLL%" (
  echo [ERROR] Built DLL not found: %SOURCE_DLL%
  exit /b 1
)

if not exist "%DEST_DIR%" (
  mkdir "%DEST_DIR%" || (
    echo [ERROR] Could not create destination directory: %DEST_DIR%
    exit /b 1
  )
)

copy /Y "%SOURCE_DLL%" "%DEST_DLL%" >nul
if errorlevel 1 (
  echo [ERROR] Failed to copy DLL to: %DEST_DLL%
  exit /b 1
)

echo [OK] Build complete.
echo [OK] Copied DLL: %DEST_DLL%
echo [NOTE] Run from repo root: bin\build.bat [--release]
exit /b 0

:usage
echo Usage:
echo   bin\build.bat           ^(debug build^)
echo   bin\build.bat --release ^(release build^)
exit /b 1

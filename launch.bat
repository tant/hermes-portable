@echo off
REM ============================================================================
REM Hermes Agent - Portable Launcher (Windows shim)
REM Delegates to launch.ps1 so double-click and drag-and-drop still work.
REM ============================================================================
powershell -ExecutionPolicy Bypass -NoProfile -File "%~dp0launch.ps1" %*

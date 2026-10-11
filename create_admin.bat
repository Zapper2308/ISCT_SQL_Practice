@echo off
setlocal
cd /d "%~dp0"

if not exist ".venv\Scripts\python.exe" (
  echo Run run.bat once first so the virtual environment gets created.
  pause
  exit /b 1
)

".venv\Scripts\python.exe" manage.py create_admin %*
pause

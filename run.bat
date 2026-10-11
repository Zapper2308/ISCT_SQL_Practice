@echo off
setlocal
cd /d "%~dp0"
title SQL Query Practice

if not exist ".env" (
  echo [ERROR] .env file not found. Create it from the template in README.md first.
  pause
  exit /b 1
)

if not exist ".venv\Scripts\python.exe" (
  echo Creating virtual environment in .venv ...
  py -3 -m venv .venv 2>nul || python -m venv .venv
  if errorlevel 1 (
    echo [ERROR] Could not create a virtual environment. Install Python 3.10+ from python.org and tick "Add to PATH".
    pause
    exit /b 1
  )
)

echo Installing / checking requirements ...
".venv\Scripts\python.exe" -m pip install --disable-pip-version-check -q -r requirements.txt
if errorlevel 1 (
  echo [ERROR] Failed to install requirements.
  pause
  exit /b 1
)

echo Applying database migrations ...
".venv\Scripts\python.exe" manage.py migrate --noinput
if errorlevel 1 (
  echo [ERROR] Database migration failed.
  pause
  exit /b 1
)

echo Starting the app with hot-reload - press Ctrl+C to stop.
".venv\Scripts\python.exe" manage.py runserver

pause

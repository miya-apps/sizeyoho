@echo off
setlocal
set "CHROME=%ProgramFiles%\Google\Chrome\Application\chrome.exe"
if not exist "%CHROME%" set "CHROME=%ProgramFiles(x86)%\Google\Chrome\Application\chrome.exe"
if not exist "%CHROME%" (
  echo Google Chromeが見つかりませんでした。
  pause
  exit /b 1
)
set "BASE=%~dp0"
set "BASE_URL=%BASE:\=/%"
start "" "%CHROME%" "file:///%BASE_URL%slide-01-growth-curve.html"

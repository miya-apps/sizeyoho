@echo off
setlocal
set "CHROME=%ProgramFiles%\Google\Chrome\Application\chrome.exe"
if not exist "%CHROME%" set "CHROME=%ProgramFiles(x86)%\Google\Chrome\Application\chrome.exe"
set "BASE=%~dp0"
set "BASE_URL=%BASE:\=/%"
set "HTML=file:///%BASE_URL%slide-01-growth-curve.html"
set "OUT_DIR=%BASE%..\..\store-submission\ios-6.9"
set "OUT=%OUT_DIR%\slide-01-growth-curve.png"

if not exist "%CHROME%" (
  echo Google Chromeが見つかりませんでした。
  pause
  exit /b 1
)
if not exist "%OUT_DIR%" mkdir "%OUT_DIR%"
if exist "%OUT%" del /q "%OUT%"

echo PNGを書き出しています...
"%CHROME%" --headless=new --disable-gpu --hide-scrollbars --window-size=1290,2796 --force-device-scale-factor=1 --virtual-time-budget=8000 --run-all-compositor-stages-before-draw --screenshot="%OUT%" "%HTML%"
if errorlevel 1 goto :failed

powershell -NoProfile -Command "Add-Type -AssemblyName System.Drawing; $image=[System.Drawing.Image]::FromFile('%OUT%'); try{if($image.Width -ne 1290 -or $image.Height -ne 2796){exit 1}}finally{$image.Dispose()}"
if errorlevel 1 goto :failed

if exist "%OUT%" (
  echo 完了: %OUT%
  start "" "%OUT%"
  exit /b 0
)

:failed
echo 失敗しました。Chromeと1290x2796の出力を確認してください。
pause
exit /b 1

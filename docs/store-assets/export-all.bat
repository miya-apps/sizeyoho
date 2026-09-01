@echo off
setlocal
set "CHROME=%ProgramFiles%\Google\Chrome\Application\chrome.exe"
if not exist "%CHROME%" set "CHROME=%ProgramFiles(x86)%\Google\Chrome\Application\chrome.exe"
set "BASE=%~dp0"
set "BASE_URL=%BASE:\=/%"
set "OUT_DIR=%BASE%..\..\store-submission\ios-6.9"
set "FLAGS=--headless=new --disable-gpu --hide-scrollbars --window-size=1290,2796 --force-device-scale-factor=1 --virtual-time-budget=8000 --run-all-compositor-stages-before-draw"

if not exist "%CHROME%" (
  echo Google Chromeが見つかりませんでした。
  pause
  exit /b 1
)

if not exist "%OUT_DIR%" mkdir "%OUT_DIR%"

echo 全6枚を書き出しています...

call :capture slide-01-growth-curve
if errorlevel 1 goto :failed
call :capture slide-02-sd-score
if errorlevel 1 goto :failed
call :capture slide-03-clothing-guide
if errorlevel 1 goto :failed
call :capture slide-04-shoe-guide
if errorlevel 1 goto :failed
call :capture slide-05-overview
if errorlevel 1 goto :failed
call :capture slide-06-diaper-guide
if errorlevel 1 goto :failed

powershell -NoProfile -Command "$files=Get-ChildItem -LiteralPath '%OUT_DIR%' -Filter 'slide-0*.png'; if($files.Count -ne 6){exit 1}; Add-Type -AssemblyName System.Drawing; foreach($file in $files){$image=[System.Drawing.Image]::FromFile($file.FullName); try{if($image.Width -ne 1290 -or $image.Height -ne 2796){exit 1}}finally{$image.Dispose()}}"
if errorlevel 1 goto :failed

echo.
echo 完了:
dir /b "%OUT_DIR%\slide-0*.png"
pause
exit /b 0

:capture
set "OUT=%OUT_DIR%\%~1.png"
if exist "%OUT%" del /q "%OUT%"
"%CHROME%" %FLAGS% --screenshot="%OUT%" "file:///%BASE_URL%%~1.html"
if errorlevel 1 exit /b 1
if not exist "%OUT%" exit /b 1
exit /b 0

:failed
echo.
echo 書き出しまたは1290x2796の寸法確認に失敗しました。
pause
exit /b 1

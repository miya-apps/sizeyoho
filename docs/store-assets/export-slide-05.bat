@echo off
setlocal
set CHROME=C:\Program Files\Google\Chrome\Application\chrome.exe
set HTML=file:///C:/grow_app/docs/store-assets/slide-05-overview.html
set OUT=C:\grow_app\docs\store-assets\slide-05-overview.png

echo PNGを書き出しています...
"%CHROME%" --headless=new --disable-gpu --hide-scrollbars --window-size=1290,2796 --force-device-scale-factor=1 --virtual-time-budget=8000 --run-all-compositor-stages-before-draw --screenshot="%OUT%" "%HTML%"

if exist "%OUT%" (
  echo 完了: %OUT%
  start "" "%OUT%"
) else (
  echo 失敗しました。
  pause
)

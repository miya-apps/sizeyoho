@echo off
setlocal
set CHROME=C:\Program Files\Google\Chrome\Application\chrome.exe
set BASE=C:\grow_app\docs\store-assets
set FLAGS=--headless=new --disable-gpu --hide-scrollbars --window-size=1290,2796 --force-device-scale-factor=1 --virtual-time-budget=8000 --run-all-compositor-stages-before-draw

echo 全5枚を書き出しています...

"%CHROME%" %FLAGS% --screenshot="%BASE%\slide-01-growth-curve.png" "file:///C:/grow_app/docs/store-assets/slide-01-growth-curve.html"
"%CHROME%" %FLAGS% --screenshot="%BASE%\slide-02-sd-score.png" "file:///C:/grow_app/docs/store-assets/slide-02-sd-score.html"
"%CHROME%" %FLAGS% --screenshot="%BASE%\slide-03-clothing-guide.png" "file:///C:/grow_app/docs/store-assets/slide-03-clothing-guide.html"
"%CHROME%" %FLAGS% --screenshot="%BASE%\slide-04-shoe-guide.png" "file:///C:/grow_app/docs/store-assets/slide-04-shoe-guide.html"
"%CHROME%" %FLAGS% --screenshot="%BASE%\slide-05-overview.png" "file:///C:/grow_app/docs/store-assets/slide-05-overview.html"

echo.
echo 完了:
dir /b "%BASE%\slide-0*.png"
pause

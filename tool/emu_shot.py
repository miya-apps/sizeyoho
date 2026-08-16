# エミュレータ画面のスクリーンショットを取る補助スクリプト。
# PowerShell の > リダイレクトはバイナリを壊すため、subprocess で受ける。
# 使い方: python tool/emu_shot.py [出力パス]
import subprocess
import sys

out = sys.argv[1] if len(sys.argv) > 1 else 'tmp/emu.png'
data = subprocess.run(
    ['adb', '-s', 'emulator-5554', 'exec-out', 'screencap', '-p'],
    capture_output=True,
).stdout
with open(out, 'wb') as f:
    f.write(data)
print(out, len(data))

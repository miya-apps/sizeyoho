# -*- coding: utf-8 -*-
"""アプリアイコンの一括差し替えスクリプト。

新しいアイコン画像（文字なし・正方形・フラット背景）を唯一のソースとして、
アプリ・Web・公開サイトで使う全アイコン素材を生成する。

生成物:
  assets/branding/app_icon_source.png   … ソースのコピー（1024）
  assets/branding/app_icon_art.png      … イラストのみ版（=ソースそのまま）
  assets/branding/app_icon_1024_ios.png … iOS 用（1024・不透過）
  assets/branding/icon_512_web.png      … Android/Web 用（512）
  assets/branding/ic_launcher_background.png … アダプティブ背景（フラット色）
  assets/branding/ic_launcher_foreground.png … アダプティブ前景（透過・中央配置）
  assets/branding/app_icon_wordmark.png … ワードマーク版（イラスト＋「サイズ予報」）
  docs/icon.png                         … 公開サイトの favicon / ヒーロー画像（512）
  docs/icon_wordmark.png                … 公開サイト用ワードマーク

このあと `dart run flutter_launcher_icons` を実行すると Android mipmap /
iOS AppIcon.appiconset / web/icons が再生成される。

使い方: python scripts/apply_icon.py <新アイコンのPNGパス>
"""
import sys

from PIL import Image, ImageDraw, ImageFont

ROOT = r"c:\grow_app"
SIDE = 1024

src_path = sys.argv[1]
src = Image.open(src_path).convert("RGB").resize((SIDE, SIDE), Image.LANCZOS)

# 背景色は四隅の平均（生成画像のわずかな紙目テクスチャをならす）
corners = [src.getpixel(p) for p in [(8, 8), (SIDE - 9, 8), (8, SIDE - 9), (SIDE - 9, SIDE - 9)]]
bg = tuple(sum(c[i] for c in corners) // 4 for i in range(3))
print("background color:", bg)

# ── ブランド素材（ソース・イラストのみ・iOS・Web） ──
src.save(rf"{ROOT}\assets\branding\app_icon_source.png")
src.save(rf"{ROOT}\assets\branding\app_icon_art.png")
src.save(rf"{ROOT}\assets\branding\app_icon_1024_ios.png")
src.resize((512, 512), Image.LANCZOS).save(rf"{ROOT}\assets\branding\icon_512_web.png")
src.resize((512, 512), Image.LANCZOS).save(rf"{ROOT}\docs\icon.png")

# ── アダプティブアイコン ──
# 背景: フラットな背景色1枚。
Image.new("RGB", (SIDE, SIDE), bg).save(
    rf"{ROOT}\assets\branding\ic_launcher_background.png"
)

# 前景: 背景色との色距離からイラスト部分を抜き出して透過PNGにする。
# 縁のにじみは背景色側へ溶けるが、アダプティブ背景が同色なので目立たない。
LO, HI = 30, 120  # 色距離→アルファの傾斜（LO以下=透明、HI以上=不透明）
px = src.load()
fg = Image.new("RGBA", (SIDE, SIDE), (0, 0, 0, 0))
fp = fg.load()
min_x, min_y, max_x, max_y = SIDE, SIDE, -1, -1
for y in range(SIDE):
    for x in range(SIDE):
        r, g, b = px[x, y]
        d = abs(r - bg[0]) + abs(g - bg[1]) + abs(b - bg[2])
        if d <= LO:
            continue
        a = min(255, (d - LO) * 255 // (HI - LO))
        fp[x, y] = (r, g, b, a)
        if a > 16:
            min_x = min(min_x, x)
            min_y = min(min_y, y)
            max_x = max(max_x, x)
            max_y = max(max_y, y)
print("artwork bbox:", (min_x, min_y, max_x, max_y))

art = fg.crop((min_x, min_y, max_x + 1, max_y + 1))
# セーフゾーン（中心66/108≒61%）に収まるよう、最大辺をキャンバスの50%にする。
target = int(SIDE * 0.50)
scale = target / max(art.width, art.height)
art_scaled = art.resize(
    (max(1, int(art.width * scale)), max(1, int(art.height * scale))), Image.LANCZOS
)
canvas = Image.new("RGBA", (SIDE, SIDE), (0, 0, 0, 0))
canvas.paste(
    art_scaled,
    ((SIDE - art_scaled.width) // 2, (SIDE - art_scaled.height) // 2),
    art_scaled,
)
canvas.save(rf"{ROOT}\assets\branding\ic_launcher_foreground.png")

# ── ワードマーク版（イラスト＋「サイズ予報」の文字） ──
wm = Image.new("RGB", (SIDE, SIDE), bg)
art_w = 700
art_h = int(art.height * art_w / art.width)
art_wm = art.resize((art_w, art_h), Image.LANCZOS)
wm.paste(art_wm, ((SIDE - art_w) // 2, 96), art_wm)
font = ImageFont.truetype(rf"{ROOT}\assets\fonts\ZenMaruGothic-Bold.ttf", 132)
text = "サイズ予報"
draw = ImageDraw.Draw(wm)
tb = draw.textbbox((0, 0), text, font=font)
tw = tb[2] - tb[0]
# 文字はイラストと同系の生成り色（緑背景に対するコントラストを揃える）
draw.text(((SIDE - tw) / 2, 96 + art_h + 56), text, font=font, fill=(248, 242, 230))
wm.save(rf"{ROOT}\assets\branding\app_icon_wordmark.png")
wm.save(rf"{ROOT}\docs\icon_wordmark.png")

print("done")

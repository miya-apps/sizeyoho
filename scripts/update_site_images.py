# -*- coding: utf-8 -*-
"""サイト用スクショの配置スクリプト（2026-08-08 差し替え）。

ユーザー提供の最新スクショを docs/screenshots/ へ最適化して配置する。
- アプリ画面（576x1024）: RGBのまま optimize 保存
- 共有用正方形（1024x1024）: 512x512 に縮小して256色パレットに減色
"""
import os

from PIL import Image

SRC = r"C:\Users\sawaw\.cursor\projects\c-grow-app\assets"
DST = r"c:\grow_app\docs\screenshots"

screens = {
    "localhost_8083__iPhone_SE___21_-257e37e6-b0fd-4164-8c5e-0f86ea50d7ba.png": "growth-curve.png",
    "localhost_8083__iPhone_SE___22_-f8d1fc37-e06a-4ff1-b7cb-2251d7f173bb.png": "sd-score.png",
    "localhost_8083__iPhone_SE___23_-e2175e82-5976-465f-9a6a-5b94d9735430.png": "diaper-guide.png",
    "localhost_8083__iPhone_SE___24_-d74a01b1-f8b1-46f6-a0b4-01fdcd0e90f2.png": "clothing-guide.png",
    "localhost_8083__iPhone_SE___25_-fd911baf-425b-4d44-9027-8c49b8cf4e05.png": "shoe-guide.png",
}

squares = {
    "SD________20260808_0949-29080a87-ae20-4ec4-a1ee-b2bf913adfad.png": "share-sd-score.png",
    "______________20260808_0949-381da4c4-f358-41c3-8b2c-28f614d729a9.png": "share-diaper.png",
    "____________20260808_0949-abf9332f-47f0-4dfb-8a89-8e80bb52d2cd.png": "share-shoe.png",
    "_____________20260808_0949-a21c8676-c244-47c6-bff6-dc8a0ea7d5df.png": "share-clothing.png",
}


def find(name_suffix):
    for f in os.listdir(SRC):
        if f.endswith(name_suffix):
            return os.path.join(SRC, f)
    raise FileNotFoundError(name_suffix)


for src_name, dst_name in screens.items():
    im = Image.open(find(src_name)).convert("RGB")
    im.save(os.path.join(DST, dst_name), optimize=True)
    print("saved:", dst_name, im.size)

for src_name, dst_name in squares.items():
    im = Image.open(find(src_name)).convert("RGB")
    im = im.resize((512, 512), Image.LANCZOS)
    im = im.quantize(colors=256, method=Image.MEDIANCUT)
    im.save(os.path.join(DST, dst_name), optimize=True)
    print("saved:", dst_name, im.size)

old = os.path.join(DST, "share-growth-curve.png")
if os.path.exists(old):
    os.remove(old)
    print("removed: share-growth-curve.png")
print("done")

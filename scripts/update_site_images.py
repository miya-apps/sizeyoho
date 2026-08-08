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

# 2026-08-08 撮り直し版（右下のブラウザオーバーレイ写り込みなし）
screens = {
    "localhost_8083__iPhone_SE___28_-4e8e2bf9-0e21-4459-ae07-2984a5306c01.png": "growth-curve.png",
    "localhost_8083__iPhone_SE___29_-235113d0-5509-4439-97da-6a793e3abefd.png": "sd-score.png",
    "localhost_8083__iPhone_SE___31_-3ebc4ab1-914a-4290-856b-4a4a6083151f.png": "diaper-guide.png",
    "localhost_8083__iPhone_SE___30_-02059530-7c9b-4a2f-9bf5-ba6880a6b8f5.png": "clothing-guide.png",
    "localhost_8083__iPhone_SE___32_-572fbefa-1a72-4afd-9d5e-8fa132421f47.png": "shoe-guide.png",
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

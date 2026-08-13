# ランチャーアイコンの絵柄を拡大する（「絵が小さい」フィードバック対応）。
#
# 拡大率の根拠：
# - Android アダプティブアイコンは中央 66/108（直径61%）の円が安全圏。
#   現状の絵の最大半径は安全圏の 0.901 倍なので、円形マスクでも欠けない
#   上限は約 1.11 倍。少し余裕を見て 1.08 倍にする。
# - iOS / Web はフルブリード表示で絵が幅の50%しかなく余白が広いため、
#   1.25 倍（幅の約62%）まで上げる。
import os

from PIL import Image

BRANDING = os.path.join('assets', 'branding')


def zoom_center(im: Image.Image, factor: float) -> Image.Image:
    """画像を中心基準で factor 倍に拡大し、元のサイズに切り抜く。"""
    w, h = im.size
    big = im.resize((round(w * factor), round(h * factor)), Image.LANCZOS)
    bw, bh = big.size
    left = (bw - w) // 2
    top = (bh - h) // 2
    return big.crop((left, top, left + w, top + h))


def process(name: str, factor: float) -> None:
    path = os.path.join(BRANDING, name)
    im = Image.open(path)
    zoom_center(im, factor).save(path)
    print(f'{name}: x{factor}')


process('ic_launcher_foreground.png', 1.08)
process('app_icon_1024_ios.png', 1.25)
process('icon_512_web.png', 1.25)

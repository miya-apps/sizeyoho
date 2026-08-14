# サイト（docs/）掲載用スクリーンショットの変換スクリプト。
#
# 入力（提供された画像・エミュレータで書き出した画像）を、
# - アプリ画面：575x1024 RGB（ヒーロー・スライド埋め込み用）
# - 共有サンプル：512x512 256色パレット（ページ内サムネイル用）
# に変換して docs/screenshots へ配置する。
#
# 使い方：SRC_APP / SRC_SHARE のパスを差し替えて `python tool/update_site_shots.py`
import os

from PIL import Image

DOCS = os.path.join('docs', 'screenshots')

ASSETS = r'C:\Users\sawaw\.cursor\projects\c-grow-app\assets'
PREFIX = (
    'c__Users_sawaw_AppData_Roaming_Cursor_User_workspaceStorage_'
    '25e9acfbf3d2ba846aae4099a8d16413_images_'
)

# アプリ画面（575x1024）：提供UUID → サイトのファイル名
SRC_APP = {
    f'{PREFIX}192.168.150.105_8083__iPhone_SE___6_'
    '-6a7e7ab0-7888-472f-8c43-4737c4e32030.png': 'growth-curve.png',
    f'{PREFIX}192.168.150.105_8083__iPhone_SE___10_'
    '-ac8829a2-7f92-4340-8eac-2456cea7d346.png': 'shoe-guide.png',
    f'{PREFIX}192.168.150.105_8083__iPhone_SE___8_'
    '-eb2c5d97-f6e0-4f13-87b7-56eaea0140ae.png': 'diaper-guide.png',
    f'{PREFIX}192.168.150.105_8083__iPhone_SE___9_'
    '-3f91a141-28b2-4a3f-9699-55df1bb69deb.png': 'clothing-guide.png',
}

# 共有サンプル（正方形）：エミュレータから取得した最新の書き出し画像
# `python tool/update_site_shots.py` 実行前に site-shots-src/ に置く。
SRC_SHARE = {
    'share-growth-curve.png': 'share-growth-curve.png',
    'share-sd-score.png': 'share-sd-score.png',
    'share-clothing.png': 'share-clothing.png',
    'share-diaper.png': 'share-diaper.png',
    'share-shoe.png': 'share-shoe.png',
}
SHARE_SRC_DIR = 'site-shots-src'


def save_app_shot(src: str, dst: str) -> None:
    im = Image.open(src).convert('RGB')
    if im.size != (575, 1024):
        im = im.resize((575, 1024), Image.LANCZOS)
    im.save(dst, optimize=True)
    print(f'{dst}: {os.path.getsize(dst) // 1024}KB')


def save_share_shot(src: str, dst: str) -> None:
    im = Image.open(src).convert('RGB')
    im = im.resize((512, 512), Image.LANCZOS)
    # 文字とベタ塗り主体なので256色パレットで十分きれい＆軽い。
    im = im.quantize(colors=256, method=Image.Quantize.MEDIANCUT, dither=0)
    im.save(dst, optimize=True)
    print(f'{dst}: {os.path.getsize(dst) // 1024}KB')


if __name__ == '__main__':
    for name, out in SRC_APP.items():
        src = os.path.join(ASSETS, name)
        if os.path.exists(src):
            save_app_shot(src, os.path.join(DOCS, out))
        else:
            print(f'skip (not found): {name}')
    for name, out in SRC_SHARE.items():
        src = os.path.join(SHARE_SRC_DIR, name)
        if os.path.exists(src):
            save_share_shot(src, os.path.join(DOCS, out))
        else:
            print(f'skip (not found): {name}')

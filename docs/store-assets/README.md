# ストア用プロモ画像（HTML → PNG）

## いちばん簡単

`export-all.bat` を **ダブルクリック** → 全6枚の PNG が一括生成されます。

個別確認用は `export-slide-01.bat` と `export-slide-05.bat` です。
原寸PNGは追跡済みのWeb画像を上書きせず、Git対象外の
`store-submission/ios-6.9/`へ出力します。
App Store用の全6枚はGoogle Fontsへ通信せず、repo内のZen Maru Gothicを読み込むため、
オフラインでも同じフォントで書き出せます。

書き出し直後は 1290×2796（ストア提出用の原寸）です。Web に置くときは
ページを軽くするため 472×1024 に縮小＋256色化しています（現在コミット
されている PNG は Web 用の縮小版）。ストア提出時は再書き出ししてください。

---

## スライド構成（ストア・Web 共通の並び）

| 順 | PNG | 内容 |
|----|-----|------|
| **1** | `slide-05-overview.png` | 全体訴求（成長曲線＋洋服ガイド合成） |
| 2 | `slide-01-growth-curve.png` | 成長曲線 |
| 3 | `slide-02-sd-score.png` | SDスコア |
| 4 | `slide-03-clothing-guide.png` | 洋服ガイド |
| 5 | `slide-04-shoe-guide.png` | 靴ガイド |
| 6 | `slide-06-diaper-guide.png` | おむつガイド |

## スライド詳細

| # | HTML | スクショ | 大きい文字 | 小さい文字 |
|---|------|----------|------------|------------|
| 1 | `slide-05-overview.html` | 成長曲線＋洋服ガイド | 服・靴・おむつのサイズを、まとめて予報 | 成長記録と足長から、買い替え時期が見える |
| 2 | `slide-01-growth-curve.html` | 成長曲線 | 母子手帳の成長記録を、アプリでも | 健診のたびに、身長・体重の伸びをすぐ確認できる |
| 3 | `slide-02-sd-score.html` | SDスコア | 健診の準備に、成長の記録を | 身長・体重のSDスコアをいつでも確認できる |
| 4 | `slide-03-clothing-guide.html` | 洋服ガイド | 来シーズン、何cmを買えばいい？ | 成長トレンドから季節ごとのサイズを予報 |
| 5 | `slide-04-shoe-guide.html` | 靴ガイド | 「足痛い」と言われる前に、気づける | 小さくなる前に、買い替えのタイミングがわかる |
| 6 | `slide-06-diaper-guide.html` | おむつガイド | おむつのサイズアップ、いつ？に答える | 体重の記録から、切り替えの時期を先読み |

---

## サイズ

- **1290 × 2796 px**（現在のApp Store Connectで受け付けられる
  iPhone 6.9インチ用サイズ）

Google Play向け画像へはそのまま流用せず、今回Android素材は変更しません。

App Store提出前には、各HTML内の画面部分をiOS Simulatorまたは実機で
撮り直した画像へ差し替えてください。raw PNGは追跡済み画像を上書きせず、repo rootの
`store-submission/ios-raw/`へ次の名前で置きます。

- `growth-curve.png`
- `sd-score.png`
- `clothing-guide.png`
- `shoe-guide.png`
- `diaper-guide.png`

各HTMLはこのGit対象外入力先を優先し、rawが未配置の間だけ`docs/screenshots/`へfallbackします。
`export-all.bat`で合成後、原寸出力は`store-submission/ios-6.9/`に生成されます。
現在のPNGは構成・コピー確認用のWeb
縮小版であり、そのまま提出する原寸ファイルではありません。
個別slideのphone幅は1290:2796のiOS画面がheadline・brandと重ならない900pxへ
調整済みですが、正式画面へ差し替えた後に6枚すべての上下切れを目視確認します。

## 注意

- スクショ内の子ども名「みらい」はスクショ用ダミーデータの名前（実在の記録ではない）

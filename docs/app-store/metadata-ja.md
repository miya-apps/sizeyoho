# App Store掲載情報（日本語・入力用ドラフト）

最終更新: 2026-09-01

## 基本情報

| 項目 | 入力案 |
|---|---|
| アプリ名 | サイズ予報 |
| サブタイトル | 子どもの服・靴・おむつを先読み |
| Primary Category | ライフスタイル（推奨） |
| Secondary Category | ヘルスケア／フィットネス（推奨） |
| Bundle ID | `com.miyaapps.sizeyoho`（Apple側で利用可能か確認前） |
| SKU | `sizeyoho-ios`（App Store Connect内部値の案） |
| Version | `1.0.0` |
| Build | `8`（未使用の場合）／実際にuploadする未使用値`N` |
| Copyright | `2026 MIYA APPS`（案。法的な権利者表記として本人確認） |
| Support URL | `https://miyaapps.com/sizeyoho/contact.html` |
| Marketing URL | `https://miyaapps.com/sizeyoho/` |
| Privacy Policy URL | `https://miyaapps.com/sizeyoho/privacy.html` |

カテゴリは医療診断アプリではないため「メディカル」を選ばない案です。最終選択は
App Store Connectでユーザー本人が確認してください。

## プロモーションテキスト

> 身長・体重・足長を記録すると、服・靴・おむつの今と次のサイズがひと目でわかります。成長曲線や受診用PDF、機種変更に備えたバックアップにも対応。

## 説明文

> 「サイズ予報」は、お子様の成長記録と、服・靴・おむつのサイズ選びをひとつにまとめた保護者向けアプリです。
>
> 身長・体重を記録すると、成長曲線とSDスコアでこれまでの伸びを確認できます。成長記録と足長をもとに、季節ごとの洋服サイズ、靴の買い替え時期、おむつサイズの目安も確認できます。
>
> 主な機能
>
> ・お子様を最大6名まで登録<br>
> ・身長、体重、足長の記録<br>
> ・成長曲線とSDスコア<br>
> ・洋服、靴、おむつのサイズガイド<br>
> ・成長記録の履歴、編集<br>
> ・お誕生日の思い出と写真<br>
> ・健診や受診時に見せやすいPDFレポート<br>
> ・ファイルによるバックアップと復元
>
> サイズ予報 Pro
>
> ・靴サイズと購入時期の先読み<br>
> ・グラフ、ガイド画像の保存・共有<br>
> ・写真を除く記録のオンライン自動バックアップ<br>
> ・広告非表示
>
> Pro版は月額または年額の自動更新サブスクリプションです。料金は購入画面にApp Storeから取得した現在の価格で表示されます。購入の復元、プランの管理・解約はアプリの設定から案内しています。Google PlayとApp Storeの間でPro購入は引き継がれません。
>
> 本アプリの予測や表示は成長・サイズ選びの目安であり、診断や治療を目的とするものではありません。健康や発育に関する心配がある場合は、医師などの専門家へご相談ください。
>
> 利用規約：https://miyaapps.com/terms.html<br>
> プライバシーポリシー：https://miyaapps.com/sizeyoho/privacy.html

## キーワード

`子ども,成長記録,身長,体重,服サイズ,靴サイズ,おむつ,成長曲線,育児`

UTF-8で92バイト。App Store Connectの100バイト枠内です。

## 年齢レーティング

実際のレーティングはApp Store Connectの最新質問票で決まるため、現時点では
わかりません。コード上は暴力、性的表現、ギャンブル、ユーザー生成コンテンツ、
アプリ内Webブラウザを確認できません。広告はあり、利用者は保護者を想定します。
Kids Categoryには登録しません。

質問票では少なくとも次を1項目ずつ実態どおり確認します。

- Advertising（AdMobバナーあり）
- Health or Wellness Topics（成長曲線・SDスコア・成長表示あり）
- Medical or Treatment Information（受診用PDFと免責文はあるが診断・治療機能はない）
- Unrestricted Web Access / External Links（外部URLは開くがアプリ内ブラウザではない）
- User-Generated Content / Messaging（利用者間投稿・メッセージ機能なし）
- Contests / Gambling / Violence / Sexual Content等（コード上は確認できない）

Health/Medical関連の回答と頻度によって9+または13+等になる可能性があります（推測です）。
年齢を先に決め打ちせず、全回答後にApp Store Connectが示す最終値を採用します。

## App Review情報

### Sign-in required

いいえ。子どもの登録、成長記録、サイズガイド、PDFはログインなしで確認できます。
オンライン自動バックアップだけがPro購入とAppleサインインを必要とします。

### 審査用ログイン情報

不要です。固定の共有アカウントやパスワードは作成しません。Appleサインインは
審査担当者自身のSandbox環境で確認できます。

### App Review Notes（入力案）

> This is a Japanese app for parents to record a child's growth and estimate clothing, shoe, and diaper sizes. Core features do not require sign-in.
>
> To find the subscription: open Settings (bottom-right tab) > “Pro版にアップグレード”. The paywall shows the localized App Store prices for the monthly and yearly auto-renewable subscriptions. “購入を復元” is available on both the paywall and Settings.
>
> Pro features are: future shoe-size/purchase timing forecast, export/share of chart images, cloud auto-backup excluding photos, and removal of banner ads.
>
> Cloud backup sign-in on iOS uses Sign in with Apple. After signing in, account deletion is available at Settings > Pro版 > “クラウドアカウントを削除”. It deletes the Firebase account and cloud backup, and revokes the Apple authorization token. Local records remain on the device as explained in the confirmation dialog.
> A non-content deletion marker containing only the Firebase user ID and deletion time remains in Firestore solely to reject delayed writes from another signed-in device, as disclosed in the Privacy Policy.
>
> PDF export: Growth tab > top-left “画像保存” > “受診レポートPDF”. The iOS system save dialog is used.
>
> The app does not request App Tracking Transparency permission and is configured not to use IDFA. In regions where required, Google UMP is shown before any ad request; the privacy options entry then appears in Settings.
>
> Growth and size estimates are informational only and are not medical diagnosis or treatment.

### 連絡先

App Reviewの氏名、電話番号、メールアドレスはリポジトリからはわかりません。
審査中に連絡を受けられるユーザー本人の情報を入力してください。

## In-App Purchase掲載案

| 項目 | 月額 | 年額 |
|---|---|---|
| 種類 | 自動更新サブスクリプション | 自動更新サブスクリプション |
| Product ID | `sizeyoho_pro_monthly` | `sizeyoho_pro_yearly` |
| 表示名 | サイズ予報 Pro 月額 | サイズ予報 Pro 年額 |
| 期間 | 1か月 | 1年 |
| 説明 | サイズ予報 Proの全機能を1か月ごとに利用 | サイズ予報 Proの全機能を1年ごとに利用 |
| Subscription Group | `サイズ予報 Pro` | 同じグループ |
| Level | 同じレベル | 同じレベル |

価格はコードへ固定せず、App Store Connectでユーザー本人が決定します。購入画面は
`ProductDetails.price`を表示します。初回提出では2商品をアプリversionと一緒に
App Reviewへ提出します。商品ごとの審査画像はMacのSandbox動作確認後に撮ります。

月額・年額の商品別Review Notesには、両方とも次を入力します。

> Open Settings (bottom-right tab) > “Pro版にアップグレード”. This paywall displays this subscription with its localized App Store price, renewal period, Restore Purchases, Terms, and Privacy Policy links.

## スクリーンショット構成

1. 全体訴求（成長曲線＋洋服ガイド）
2. 成長曲線
3. SDスコア
4. 洋服ガイド
5. 靴ガイド
6. おむつガイド

Windows上のHTML台紙は1290×2796で出力できます。現在のPNGはWeb用縮小版です。
App Storeへ入れる画面部分は、MacでiOS Simulatorまたは実機から撮影した表示に
差し替えます。iPhone専用のためiPad用セットは不要です。

# iPhone版 App Store公開準備

最終更新: 2026-09-01
対象コミット（調査開始時）: `01d700b68ce325ae08f3cea9a21c282d958cd37b`

このディレクトリは、Windowsで完了できる準備、Macでだけ行う作業、
アカウント所有者本人が行う作業を分離した引き継ぎ資料です。Google Play
Consoleの設定、Android AAB、AndroidのversionCodeには触れません。

## 調査結果

| 項目 | 現在値・状態 |
|---|---|
| フレームワーク | Flutter / Dart |
| Dart制約 | `^3.12.2` |
| Flutter | stable、リポジトリ記録revision `c9a6c484230f8b5e408ec57be1ef71dee1e77020` |
| アプリ名 | サイズ予報 |
| version | `1.0.0` |
| build number | `8`（`pubspec.yaml`の現在値。実upload時はApp Store Connectで未使用の`N`） |
| Android ID | `com.miyaapps.sizeyoho` |
| iOS Bundle ID | コード上の候補を `com.miyaapps.sizeyoho` に統一。Apple側で利用可能か未確認 |
| iOS最低OS | 15.0へ統一 |
| 対象端末 | iPhoneのみ（Xcode device family 1） |
| iOS構成 | Xcode project/workspaceあり。Flutter Swift Package Manager構成 |
| CocoaPods | 現状不要。Podfileなしは欠落ではない |
| 向き | 縦向き |

### 主なパッケージ

`firebase_core`、`firebase_auth`、`cloud_firestore`、`google_mobile_ads`、
`in_app_purchase`、`in_app_purchase_android`、`shared_preferences`、
`image_picker`、`gal`、`file_saver`、`file_selector`、`share_plus`、
`url_launcher`、`pdf`、`fl_chart`、`intl`、`flutter_svg`。

`pubspec.yaml`の直接依存制約は次のとおりです。Macでは`pubspec.lock`を維持して
`flutter pub get`し、勝手にmajor upgradeしません。

| パッケージ | 制約 | パッケージ | 制約 |
|---|---:|---|---:|
| cupertino_icons | ^1.0.8 | fl_chart | ^1.2.0 |
| intl | ^0.20.2 | image_picker | ^1.2.2 |
| shared_preferences | ^2.2.3 | phosphoricons_flutter | ^1.0.0 |
| file_saver | ^0.4.0 | pdf | ^3.13.0 |
| file_selector | ^1.1.0 | firebase_core | ^4.11.0 |
| firebase_auth | ^6.5.4 | cloud_firestore | ^6.6.0 |
| url_launcher | ^6.3.1 | web | ^1.1.1 |
| google_mobile_ads | ^9.0.0 | in_app_purchase | ^3.3.0 |
| in_app_purchase_android | ^0.5.1 | flutter_svg | ^2.3.0 |
| share_plus | ^13.3.0 | gal | ^2.3.3 |

現在のlock値で制約表と異なる直接依存は`cupertino_icons 1.0.9`、
`shared_preferences 2.5.5`、`url_launcher 6.3.2`です。StoreKit adapterは推移依存
`in_app_purchase_storekit 0.4.10+1`です。

### iOS権限・起動画面

| Info.plist key | 用途 |
|---|---|
| `NSCameraUsageDescription` | プロフィール・誕生日写真の撮影 |
| `NSPhotoLibraryUsageDescription` | プロフィール・誕生日写真の選択 |
| `NSPhotoLibraryAddUsageDescription` | 成長グラフ・サイズ予報画像の保存 |

位置情報、マイク、連絡先、Bluetooth、ATTの権限文はありません。Launch Screenは
白背景＋透明1px画像のため実質白画面です。素材欠落ではありませんが、実機で初回frameとの
つながりを確認し、変更する場合も既存App Icon素材だけを使います。

### 外部URL

| 種類 | URL |
|---|---|
| Marketing | `https://miyaapps.com/sizeyoho/` |
| Support / Contact | `https://miyaapps.com/sizeyoho/contact.html` |
| Privacy | `https://miyaapps.com/sizeyoho/privacy.html` |
| Terms | `https://miyaapps.com/terms.html` |
| Disclaimer | `https://miyaapps.com/disclaimer.html` |
| Contact form | Googleフォーム（`lib/app/app_info.dart`に固定URL） |
| Subscription management | `https://apps.apple.com/account/subscriptions`（iOSのみ） |
| Icon licenses | Tabler、Lucide GitHub、Streamline、CC BY 4.0（`about_app_screen.dart`） |

おむつ商品情報にはメーカー等の参照URLが17個あります。OS依存処理はなく、代表URLを
TestFlightで法務、課金管理、問い合わせ、license、商品参照の各カテゴリを確認します。
公開Privacyは現在2026-08-18の旧版で、ローカルの更新済み
`docs/privacy.html`とは一致していません。

### iOSで追加確認が必要な依存関係

| パッケージ | Windowsで行った準備 | Macで行う確認 |
|---|---|---|
| Firebase | iOS値をGit外のDart defineから読む仕組みを追加 | 実値で初期化、Auth/Firestore実動作 |
| Firebase Auth | Apple capabilityとアカウント削除処理を追加 | Apple provider、再認証、削除、token revoke |
| Google Mobile Ads | iOS App ID/Unit ID/SKAdNetworkを監査、UMPを追加 | 実SDK版、Privacy Report、実広告 |
| In-App Purchase | StoreKit 2の現在権利確認、復元、ストア価格表示を追加 | 商品同期、Sandbox/TestFlight購入 |
| file_saver | iOSもシステム保存ダイアログを使用 | FilesへのPDF/JSON保存 |
| file_selector | JSON UTI `public.json` を追加 | Files/iCloud Driveから読込 |
| image_picker / gal | Usage Descriptionは設定済み | 写真選択・撮影・保存 |
| share_plus | iPhoneのみを対象化 | 共有シート |

## Android版との主要機能差

| 機能 | 共通実装 | iOS状態 |
|---|---:|---|
| 子どもの登録 | はい | MacでUI確認待ち |
| 身長・体重・成長曲線・SD | はい | MacでUI確認待ち |
| 服・靴・おむつサイズ予報 | はい | MacでUI確認待ち |
| PDF | はい | 保存先選択をiOS対応済み、実機確認待ち |
| ローカル/手動バックアップ | はい | JSON UTI対応済み、実機確認待ち |
| 広告 | IDだけOS別 | iOS専用IDあり、UMP追加済み、実機確認待ち |
| Pro課金 | 商品設計はOS別 | StoreKit 2対応を追加、商品登録・実機確認待ち |
| Pro購入権利のOS間移行 | 共通backendなし | Google PlayとApp Storeは別購入。本人承認待ち |
| クラウドバックアップ | 共通Firebase | iOS Firebase実値とApple provider設定待ち |
| クラウドのサインイン | OS別 | iOSはAppleのみ。Android/WebのGoogle導線は維持 |
| 法務・問い合わせ | 共通 | HTTPS導線あり |

iOSでGoogleログインを表示しないのは、Firebase公式がネイティブGoogleログイン
には別途`google_sign_in`を必要としており、未公開iOSへ壊れた導線を出さない
ためです。iOSではAppleログインを使用します。Androidの表示・商品ID・Play
Billing構成は変更していません。

このため、AndroidでGoogleログインして作成したFirebase UIDと、iPhoneのAppleログインで
作成するUIDは別です。AndroidのクラウドバックアップをiPhoneから直接復元できません。
移行時はAndroidでJSONファイルを書き出し、iPhoneで読み込みます。iOSのGoogleログインを
別途実装するか、この仕様差を受け入れるかはユーザー判断が必要で、アプリ内にも説明を
追加しています。

購入権利についても共通のentitlement backendがないため、Google Playで購入した
ProはApp Storeで復元できず、逆も同じです。現状のまま公開する場合は別購入となることを
本人が承認し、購入画面・FAQ・公開サイトで利用者へ明記します。共通購入にする場合は、
検証・account linking・返金/失効反映を行うbackendの別設計が必要です。

## 最初の4分類

### 1. Windowsでできる作業

- Dart/iOS設定の監査と修正
- Bundle ID候補、iOS 15、iPhone-only、entitlementの準備
- PDF/JSON保存、Safe Area、広告同意、課金権利、アカウント削除の実装
- 秘密情報の`.gitignore`強化
- アイコン、Launch Screen、スクリーンショット台紙の検査
- App Store文案、Privacy回答案、審査メモ、テスト表の作成
- Apple/Google/Firebase公式要件の確認
- Windows用スクリーンショット書き出しバッチのパス固定解除

### 2. MacBookが必要な作業

- 必須Xcode/iOS SDKでSwiftPM依存解決
- iOS buildとXcode compile（Windowsで済みの`analyze/test`もMacで再確認）
- Signing、Team、provisioning、Capabilities確認
- SimulatorでSafe Area、Files、UIと正式画像用のraw screenshotを確認
- Xcode Privacy ReportとArchive内Privacy Manifestを確認
- Archive、Validate、App Store Connectへbinary upload

Uploadとraw screenshot/Privacy Report、Mac上で生じた意図したGit変更のpushが終われば、再buildが必要になるまで
Macは返却できます。App Store Connectの入力・TestFlight設定・審査提出はWindowsの
browser、TestFlight実動作はiPhoneで行います。

### 3. ユーザー本人が操作する作業

- Apple Developer Programの契約・支払い・2FA
- Bundle IDとApp Store Connectアプリレコード作成
- Paid Apps Agreement、税務、銀行情報
- Firebase iOSアプリ登録とApple認証provider設定
- AdMobのiOS App ID/Unit ID照合、European regulations message作成
- App Store Connectの2商品、価格、販売地域、ローカライズ、審査画像
- Store間でPro購入が移行しない仕様の承認、Sandbox testerとGrace Period方針
- App Privacy、年齢レーティング、Export Complianceの最終回答
- iPhoneの信頼確認、Sandbox/TestFlight操作、審査提出ボタン

パスワード、2FAコード、秘密鍵、APIキーは共有しません。

### 4. 公開ブロッカー

| 優先 | ブロッカー | 解除条件 |
|---|---|---|
| P0 | Bundle IDのApple側利用可否が未確認 | `com.miyaapps.sizeyoho`をApple Developerで登録 |
| P0 | iOS Firebaseの実値なし | Firebaseへ同Bundle IDを登録し、ローカルJSONを作成 |
| P0 | 本番Firestore Rulesの状態が不明 | 削除markerで新規writeを拒否するrepo rulesをConsoleと照合し、公開Androidのbackup回帰後に本人が反映 |
| P0 | Appleログインのサーバー側設定なし | Apple/Firebaseのprovider設定と実機試験 |
| P0 | App Store IAP商品が未確認 | 2商品を作成し、Sandbox/TestFlight購入・失効・復元を完走 |
| P0 | Macでビルド未実施 | Xcode 26系/iOS 26 SDKでArchive成功 |
| P0 | App Privacy最終値未確定 | Xcode Privacy Report、AdMob設定、実装を突合 |
| P0 | 公開Privacyが旧版 | `docs/privacy.html`を本番へdeployし、更新日・本文・200応答を確認 |
| P0 | クロスOSのクラウド移行仕様が未承認 | Apple-only＋JSON移行を承認、またはiOS Googleログインを別途実装 |
| P0 | Store間のPro購入移行仕様が未承認 | 別購入の明記を承認、またはentitlement backendを別途設計 |
| P0 | Flutter自動検査が未実施 | 通常のWindows環境でanalyze/test/debug APKを成功させる |
| P1 | AdMob UMP message未作成 | AdMob Privacy & messagingで公開 |
| P1 | 利用地域・法域に応じた広告同意範囲が未決定 | storefrontだけに依存せず、EU/米国州等に必要なmessage/GPP/RDPを設定 |
| P1 | 公開サイトがAndroid向け・固定価格表記 | App Store価格決定後、公開前にiOS文言・価格を整合 |
| P1 | overviewのWeb縮小画像が旧copy | App Store原寸は新HTMLから生成。Web copyも変える場合だけPNG/WebPを再生成 |
| P1 | ストア正式スクリーンショット未採取 | iOS Simulator/実機画面で6枚を完成 |
| P1 | Appleサインインbuttonの実機外観が未確認 | 最新Apple HIGとlogo・文言・配色・余白を照合 |
| P1 | Apple契約・税務・銀行の状態が不明 | Account HolderがApp Store Connectで確認 |

## Windows側で変更した内容

- iOS Bundle ID候補をAndroidと同じreverse-domainへ統一
- iOS minimum deployment targetを15.0へ統一
- ネイティブiPad対応を外し、今回の対象をiPhoneへ限定
- Sign in with Apple entitlement/capabilityを追加
- Firebase iOS値をGitへ入れずにビルドできる設定を追加
- Appleサインイン利用者の再認証、token revoke、クラウドデータ・アカウント削除を追加
- クラウドbackupをUID固定・直列化し、generation切替とchecksumで途中失敗時の破損・account間送信を防止
- iOSのGoogleログインボタンを非表示化
- StoreKit 2の検証済み`currentEntitlements`を使い、期限切れ・返金・取消を反映
- ストアのローカライズ済み価格をペイウォールへ表示
- 購入streamの初期化順と`completePurchase`のawaitを修正
- Pro状態を広告より先に読み込み
- iOS広告をStoreKit権利確認後の無料利用者だけで開始。Pro起動時はUMP/GMAも開始しない
- iOSのStoreKit権利をforeground中も1分ごとに再確認し、失効・返金・猶予終了を反映
- UMP privacy options導線、広告レーティングG、バナーのSafe Area/幅を修正
- iOSのPDF/JSONを保存先選択ダイアログへ変更
- iOS JSON file pickerへUTIを追加
- プライバシーポリシーへ広告データとアプリ内アカウント削除を反映
- 証明書、profile、App Store key、Firebase iOS実値のignoreを追加

### 共通コード変更とAndroidへの影響

- package ID、Manifest、Gradle、Android広告ID、Play商品ID、versionCodeは未変更
- `main.dart`は保存済みPro状態を先に読みますが、読込失敗時は無料状態で起動継続
- AndroidはStoreKit権利待ちをしない。ただし広告bannerはMobile Ads初期化完了後に
  loadするようになり、従来の並行初期化から安全側の順番に変わったため回帰対象
- AndroidのGoogleログインとクラウド機能は従来表示のまま。新しいアカウント削除UIはiOSだけ
- Android課金の親商品＋base plan選択は維持。商品照会失敗時の再照会導線と例外処理を追加
- PDF/JSONのAndroid保存分岐は維持
- `firestore.rules`の候補は削除marker後のwriteだけを拒否するが、本番へは未deploy。
  公開Androidの既存user・初回userでbackup/復元を回帰してから本人が反映する

AndroidのGoogleログインは今回変更していませんが、native Google認証に必要な
`google_sign_in`を使うFirebase公式実装ではありません。現在の公開版で実際に成功するかは
この環境からはわかりません。Android回帰で実機確認し、失敗する場合は公開済み版への影響が
大きいため、このiOS PRで勝手に依存追加せず別途承認を取って修正します。

ただし共通Dartコードを変更しているため「Androidへ影響なし」はまだ確定できません。
通常のWindows開発環境でAndroidの起動・広告・月額/年額購入・復元・Googleログイン・
クラウドバックアップを回帰確認するまで、PRをmainへmergeしません。

## 意図的に推測で追加していない設定

- `DEVELOPMENT_TEAM`
- Provisioning Profile / certificate
- iOS Firebase API key / App ID
- 架空のAdMob ID、商品ID
- `NSUserTrackingUsageDescription`（ATTを呼ばない方針）
- `ITSAppUsesNonExemptEncryption`（質問への回答前に固定しない）
- アプリ本体の`PrivacyInfo.xcprivacy`にRequired Reasonを推測で列挙すること

各SDKのmanifestはSwiftPM解決後のArchiveに集約されます。アプリ自身が申告すべき
Required Reason APIがあるかをMacのPrivacy Reportで確認し、必要な理由だけを追加します。

## 検証状況

- ソース、plist、Xcode project、画像寸法、URL、商品ID、広告IDを静的監査済み
- 公開中の利用規約と免責事項の本文を2026-09-01に確認。自動更新、解約、
  復元、返金、予測/医療免責はあるが、Store間のPro非移行は追記候補
- iOS用AdMob App IDとUnit IDがAndroid用と別であることを確認済み
- `SKAdNetworkItems` 50件をGoogle公式一覧と照合済み
- 1024px App IconがRGB・不透明であることを確認済み
- Flutter/Dartの自動解析・テスト・ビルドは未実施。この作業環境ではSDK依存取得を
  安全に完了できなかったため、通常のWindows環境で先に必ず実行する
- `tool/check_ios_release_config.ps1`でiOS Firebase JSONの必須項目・project・Bundle ID・Git除外を
  値を表示せず検査できる
- Android AAB作成、Play Console操作、versionCode変更は未実施

## 修正したファイル

### iOSネイティブ設定

- `ios/Flutter/AppFrameworkInfo.plist`
- `ios/Runner.xcodeproj/project.pbxproj`
- `ios/Runner/AppDelegate.swift`
- `ios/Runner/Runner.entitlements`（新規）

### アプリ実装

- `lib/main.dart`
- `lib/firebase_options.dart`
- `lib/ads/ad_banner.dart`
- `lib/app/app_shell.dart`
- `lib/cloud/cloud_backup.dart`
- `lib/export/save_to_device.dart`
- `lib/monetization/purchase_manager.dart`
- `lib/monetization/pro_paywall.dart`
- `lib/monetization/pro_status.dart`
- `lib/monetization/pro_pricing.dart`（固定価格表示を廃止したため削除）
- `lib/screens/faq_screen.dart`
- `lib/screens/privacy_policy_screen.dart`
- `lib/screens/settings_screen.dart`
- `lib/widgets/account_sign_in_sheet.dart`
- `firestore.rules`（削除marker後の新規write拒否。本人確認・Android回帰後にdeploy）

### 秘密情報・事前検査

- `.gitignore`
- `config/ios.firebase.example.json`（新規・空のtemplate）
- `tool/check_ios_release_config.ps1`（新規）

### 法務・App Store引き継ぎ

- `docs/privacy.html`
- `docs/app-store/README.md`（新規）
- `docs/app-store/account-setup-before-mac.md`（新規）
- `docs/app-store/app-privacy-ja.md`（新規）
- `docs/app-store/apple-requirements-2026-09-01.md`（新規）
- `docs/app-store/mac-runbook.md`（新規）
- `docs/app-store/metadata-ja.md`（新規）
- `docs/app-store/testflight-checklist.md`（新規）

### App Store画像台紙

- `docs/store-assets/README.md`
- `docs/store-assets/common.css`
- `docs/store-assets/export-all.bat`
- `docs/store-assets/export-slide-01.bat`
- `docs/store-assets/export-slide-05.bat`
- `docs/store-assets/open-slide-01.bat`
- `docs/store-assets/slide-01-growth-curve.html`
- `docs/store-assets/slide-02-sd-score.html`
- `docs/store-assets/slide-03-clothing-guide.html`
- `docs/store-assets/slide-04-shoe-guide.html`
- `docs/store-assets/slide-05-overview.html`
- `docs/store-assets/slide-06-diaper-guide.html`

## 関連資料

- [App Store掲載文案](metadata-ja.md)
- [Apple提出要件](apple-requirements-2026-09-01.md)
- [App Privacy回答案](app-privacy-ja.md)
- [Mac前の本人アカウント設定](account-setup-before-mac.md)
- [Mac最短手順](mac-runbook.md)
- [TestFlight確認表](testflight-checklist.md)

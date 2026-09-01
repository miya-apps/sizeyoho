# 借りるMacBookでの最短手順

最終更新: 2026-09-01

この文書は全体の順番です。実際にMacを操作するときは、1工程ずつ実行し、結果を
確認してから次へ進みます。パスワード、2FAコード、Recovery Key、API key、証明書は
チャットやGitHubへ貼りません。

## Macを借りる前の完了条件

次をWindowsのブラウザと普段のWindows開発環境で先に終えます。

- [ ] Apple Developer Programが有効
- [ ] `com.miyaapps.sizeyoho`が利用可能で、明示的App IDとして登録済み
- [ ] App IDでSign in with AppleとIn-App Purchaseを有効化
- [ ] App Store Connectに「サイズ予報」のapp recordを作成
- [ ] Paid Apps Agreement、税務、銀行情報が有効
- [ ] `サイズ予報 Pro` subscription groupと月額・年額2商品を作成
- [ ] Store間でPro購入が移行しない仕様を承認、またはbackend実装済み
- [ ] Billing Grace Periodの有効化範囲を決定し、Sandbox testerをシナリオ別に準備
- [ ] Firebase project `sizeyoho`へBundle IDが同じiOS appを登録
- [ ] Firebase AuthenticationでApple providerを設定
- [ ] `config/ios.firebase.example.json`をコピーし、実値を入れた
  `config/ios.firebase.json`を安全な方法でMacへ渡せる
- [ ] AdMobのiOS App ID/バナーUnit ID/Bundle IDがコードと一致
- [ ] 利用者の現在地域・法域を想定し、AdMobでEuropean regulations / U.S. states等の該当messageを公開
- [ ] AdMob audienceが保護者向け（Kids/child-directedではない）実態と一致
- [ ] DSA trader statusを完了、またはEU非配信として対象外を確認
- [ ] 更新した`docs/privacy.html`を本番公開し、Marketing/Support/Privacy/Terms/Disclaimerを確認
- [ ] 公開サイトの価格文言が確定したiOS価格と矛盾しない（準備中表示は公開まで可）
- [ ] 利用規約またはサポートにStore間のPro非移行を明記
- [ ] Apple-onlyクラウド＋JSON移行の仕様差を本人が承認、またはGoogleログインを実装済み
- [ ] 通常のWindows開発環境で`flutter analyze`、`flutter test`、
  `flutter build apk --debug`が成功（Play ConsoleやAABアップロードはしない）
- [ ] Androidで広告、課金、復元、Googleログイン、クラウド、PDF/JSONの回帰確認が成功
- [ ] `ios-app-store-prep-2026-09-01`がGitHubにpush済み

1つでも未完了なら、Macを借りる前にそこで止めます。

## 必要なソフト・物品

| 必須のソフト・物品 | 用途 | 入れ方・扱いの方針 |
|---|---|---|
| Git | clone | macOS既存またはXcode Command Line Tools |
| Xcode 26系 | iOS 26 SDK、署名、Archive | MacのOSに対応する版だけ。勝手にmacOS更新しない |
| Flutter stable revision `c9a6c484...` | project build | 専用ユーザーのホーム配下。Homebrew不要 |
| iOS Simulator runtime | UI/スクリーンショット | 必要なiPhone runtimeだけ |
| 本人所有のテスト用iPhone、対応ケーブル | 実機・課金・写真・Files | 夫のApple IDに影響する端末は使わない |
| TestFlight app | upload後のRelease build確認 | iPhoneへApp Storeから導入 |
| 十分な空き容量 | Xcode、runtime、Flutter、Archive | 不足時は既存ファイルを消さず作業停止 |

Podfileを使わないSwift Package Manager構成なので、現状CocoaPodsとHomebrewは
不要です。最初からインストールしません。

2026-04-28以降のApp Store uploadはXcode 26以降とiOS 26 SDKが必要です。
さらに、現在SwiftPMが解決し得るGoogle Mobile Ads 13.4以降はXcode 26.2以上を
要求します。したがって26.2以上を使います。

- macOS Sequoia 15.6で動かせる範囲ならXcode 26.3を候補にする
- macOS Tahoe 26.2ならXcode 26.6を候補にする
- Macの現在OSに対応する版がなければ、無断でmacOSを更新せず別のMacを使う

最終判断は[AppleのXcode system requirements](https://developer.apple.com/xcode/system-requirements)
で、その日に再確認します。

## Macを汚さない準備

### 1. まず読み取り確認だけ

Mac所有者の立ち会いで、Appleメニュー > このMacについてを開き、Mac機種、macOS版、
空き容量を確認します。まだインストール、更新、サインアウトはしません。

ターミナルで確認する場合:

```bash
sw_vers
xcodebuild -version
df -h /
```

Apple ID、ユーザー名、シリアル番号は共有不要です。

### 2. 専用macOSユーザーを優先

所有者が同意した場合、システム設定 > ユーザとグループ > ユーザを追加から、
`SizeYohoDev`などの標準ユーザーを作ります。作成時の管理者認証は所有者本人が入力し、
共有しません。

- iCloudへサインインしない
- 写真、メッセージ、YouTube、動画編集フォルダを開かない
- 専用Home、Keychain、Library、SwiftPM cacheを使う
- Xcodeへ追加するのはサイズ予報側のDeveloper Apple IDだけ

別ユーザーはXcode、Simulator、Flutterを含め数十GB使う可能性があります。空き容量が
足りない、企業管理端末、ユーザー追加禁止の場合は作らず、その理由を確認します。
既存ユーザーで作業する場合も、`~/Developer/sizeyoho-work`だけを使い、iCloudや
夫のApple ID設定を変更しません。

### 3. Xcodeをシステム全体で切り替えない

複数Xcodeがある場合、`sudo xcode-select`は使わず、作業中のシェルだけに設定します。

```bash
export SIZEYOHO_XCODE_APP="$HOME/Applications/Xcode.app"
export DEVELOPER_DIR="$SIZEYOHO_XCODE_APP/Contents/Developer"
xcodebuild -version
xcrun --sdk iphoneos --show-sdk-version
```

既存Xcodeを使う場合は、その実パスへ読み替えます。Xcode初回component installに
管理者認証が必要なら、その場で所有者へ説明して本人に入力してもらいます。

## コード取得からビルドまで

### 4. 専用フォルダへclone

```bash
mkdir -p "$HOME/Developer/sizeyoho-work"
cd "$HOME/Developer/sizeyoho-work"
git clone https://github.com/miya-apps/sizeyoho.git
cd sizeyoho
git switch ios-app-store-prep-2026-09-01
git status --short
```

公開リポジトリのHTTPS cloneを使い、夫のGitHub認証を使いません。

### 5. Flutterを確認

既存Flutterを勝手にupgradeしません。専用ユーザーにFlutterがない場合だけ、公式repoを
`$HOME/Developer/sizeyoho-tools/flutter`へ置き、projectのmetadata revisionへ合わせます。

```bash
flutter --version
flutter doctor -v
```

出力を確認し、Android StudioやCocoaPodsが無いという警告だけを理由に大量導入しません。

### 6. Firebase実値を配置

安全に渡した`ios.firebase.json`をprojectの`config/`へ置きます。内容や値は表示・共有せず、
Gitに載らないことだけ確認します。

```bash
chmod 600 config/ios.firebase.json
git check-ignore -v config/ios.firebase.json
plutil -lint config/ios.firebase.json

for key in FIREBASE_IOS_API_KEY FIREBASE_IOS_APP_ID FIREBASE_MESSAGING_SENDER_ID FIREBASE_PROJECT_ID FIREBASE_STORAGE_BUCKET FIREBASE_IOS_BUNDLE_ID; do
  test -n "$(plutil -extract "$key" raw -o - config/ios.firebase.json)" || exit 1
done
```

### 7. 依存解決と静的テスト

```bash
flutter pub get
flutter analyze
flutter test
```

1つでも失敗したらXcodeへ進まず、ログの秘密情報を除いて原因を直します。

### 8. Simulator buildとSwiftPM確認

```bash
flutter build ios --simulator \
  --dart-define-from-file=config/ios.firebase.json
open -a "$SIZEYOHO_XCODE_APP" ios/Runner.xcworkspace
```

XcodeのPackage Dependenciesで実際に解決されたGoogle Mobile Ads、Firebase等の版を
確認します。生成された`Package.resolved`の場所と内容を確認し、再現性のためcommit
対象にするかを判断します。既存packageを無断でupgradeしません。

## Xcodeの署名設定

### 9. サイズ予報側Apple IDだけを追加

Xcode > Settings > Accounts > `+` > Apple IDを選び、サイズ予報のDeveloper Apple IDで
本人がサインインします。夫のApple IDを選びません。パスワードと2FAは本人だけが入力します。

### 10. Runner targetを確認

Xcode左側でRunner project > TARGETSのRunner > Signing & Capabilitiesを開き、次を1項目ずつ確認します。

1. Automatically manage signing: ON
2. Team: サイズ予報側のDeveloper Team
3. Bundle Identifier: `com.miyaapps.sizeyoho`
4. Sign in with Apple capabilityがある
5. In-App Purchase capabilityがある
6. iOS Deployment Target: 15.0
7. Devices: iPhone

赤い署名エラーが残る場合は、証明書やprofileを手動でGitへ置かず、Apple Developerの
App ID/Team/契約を確認します。

## 動作確認

### 11. iPhone Simulator

最小クラスと大型クラスのiPhoneを各1台使い、次を確認します。

- 初回起動、白画面やクラッシュなし
- 子ども登録、キーボード、日付入力
- 成長曲線、SD、服、靴、おむつ
- Safe Area、ホームインジケータ、文字サイズ
- 画面端からの戻るジェスチャー
- JSONの保存・読込、PDFの保存
- 利用規約、Privacy、免責、問い合わせURL

カメラ、写真保存、Appleログイン、StoreKit Sandbox課金、広告は実機でも確認します。

### 12. 実機iPhone

iPhoneを接続し、所有者本人が「このコンピュータを信頼」を操作します。Developer Modeが
必要なら理由を説明して本人が有効化します。AdMobでこのiPhoneをtest deviceに登録し、
Release/TestFlightの本番Unit IDで実広告をクリックしません。

確認項目は[TestFlight確認表](testflight-checklist.md)を使います。

### 13. StoreKit Sandbox

- Windowsで準備したtester A〜Dと、それぞれの更新速度を確認する
- Sandboxのシナリオ制御が必要な場合だけ、本人所有iPhoneのDeveloper設定でSandbox Apple Accountへサインインする
- 夫や他人の本番Media & Purchases Apple IDをサインアウトしない
- App Store Connectの月額・年額商品が取得でき、現地価格が表示される
- 月額購入、年額購入、キャンセル、保留
- 購入復元
- アプリ再起動・再インストール・別端末
- 選択したSandbox更新速度で更新・失効し、ProがOFF、広告が再表示
- 返金/取消後に`currentEntitlements`から外れる

### 14. Privacy Reportの照合表を準備

この時点では[App Privacy回答案](app-privacy-ja.md)を開き、照合項目を準備します。
実際のReportはStep 15のArchive後、Step 16のUpload前にXcode Organizerから生成します。

## Archive・Upload・TestFlight

### 15. Release archiveを作る

Xcodeの署名設定が完了した状態で、App Store Connectのversion 1.0.0で処理済みの
build numberを先に確認します。`8`が未使用なら`8`、使用済みなら最大値+1を使います。
`--build-number`はiOSのこのbuildだけに適用し、`pubspec.yaml`やAndroidのversionCodeは変更しません。

```bash
export SIZEYOHO_IOS_BUILD=8
flutter build ipa --release \
  --build-name=1.0.0 \
  --build-number="$SIZEYOHO_IOS_BUILD" \
  --dart-define-from-file=config/ios.firebase.json
open -a "$SIZEYOHO_XCODE_APP" build/ios/archive/Runner.xcarchive
```

上の`8`は確認した実際の値に置き換え、version/buildを作業メモに残します。

### 16. Validate / Upload

まずOrganizerのarchive詳細からPrivacy Reportを生成します。Xcodeの版により表示名が異なる
場合があります。全SDKのdata types、tracking、Required Reason APIを回答案と照合し、
不一致があればUploadを止めます。

一致を確認後、Organizer > Distribute App > App Store Connect > Uploadを選びます。自動署名を使い、
dSYM、entitlements、Bundle ID、version/buildを確認します。Export Compliance質問は
実態に基づき本人が回答します。

### 17. 正式スクリーンショットのraw採取

iOS Simulator/実機でダミーデータを使って6画面を撮影し、フレームやcopyを足す前のraw PNGを
保存します。1290×2796、1320×2868等、その日にAppleが受け付ける6.9インチ寸法を使います。
Windowsへ持ち帰ったraw PNGは、Git対象外の`store-submission/ios-raw/`へ、
`growth-curve.png`、`sd-score.png`、`clothing-guide.png`、`shoe-guide.png`、
`diaper-guide.png`の名前で置きます。overviewはgrowth/clothingの2枚を使います。
HTMLはこの入力先を優先し、ファイルがない間だけ追跡済みWeb用画像へfallbackします。
台紙合成と最終の見切れ確認はWindowsで行い、追跡済み`docs/screenshots/`を上書きしません。

### 18. Mac返却チェックポイント

次をWindows側の安全な保管先へ移し、binaryのupload処理がApp Store Connectで始まったことを
確認したら、再buildが必要になるまでMacBookは返却できます。

- 正式raw screenshot 6枚（個人情報なし）
- Xcode Privacy Reportと監査メモ
- version/build number、upload日時、Validate/Upload結果
- 必要な場合の`xcarchive`（安全な大容量保管先だけ）

返却前にproject rootで`git status --short`を確認します。`Package.resolved`等の意図した変更は
内容を確認してcommit/pushし、`config/ios.firebase.json`、`GoogleService-Info.plist`、証明書、
秘密鍵、provisioning profileが未追跡・staging・commitへ入っていないことを再確認します。
意図不明の変更や秘密情報が見つかった場合は、削除やpushをせず止めて確認します。

`ios.firebase.json`、Apple ID情報、証明書、秘密鍵、provisioning profileはこの移送物に
混ぜません。審査中の再buildに備え、Mac所有者が同意する場合は専用macOSユーザーを残します。

### 19. TestFlight（Windows browser + iPhone）

WindowsのApp Store Connectでbuild処理完了を待ち、輸出コンプライアンス回答後、まずInternal
Testingだけへ追加します。iPhoneで確認表を全件実施し、重大問題が1件でもあれば審査へ
進みません。

### 20. App Store審査提出（Windows browser）

1. version 1.0.0へ実際にuploadしたbuild `N`を選択
2. 6枚のiPhone screenshot、説明、キーワード、URLを入力
3. App Privacy、年齢、Export Complianceを確定
4. 月額・年額IAPをversionへ紐付け
5. Review contactとReview Notesを入力
6. 自動公開/手動公開を本人が選択
7. Add for Review > Submit for Review

審査提出は外部への不可逆な操作なので、本人の画面で最終内容を読み合わせてから押します。

## 作業終了時の後片付け

審査中に再buildが必要になる可能性があるため、TestFlight/審査結果が出るまでは専用ユーザーを
保持する案が安全です。削除時はMac所有者と次を1項目ずつ確認します。

1. commit/push、Archive、必要なスクリーンショットの退避を確認
2. Xcode > Settings > Accountsで「サイズ予報側Apple ID」だけを選び、必要なら削除
3. 夫のmacOS/iCloud Apple ID、写真、メッセージ、YouTube、動画編集環境に変更がないことを確認
4. 専用`SizeYohoDev`ユーザーを残すか削除するか、Mac所有者が決定
5. 専用ユーザーを削除する場合は、そのHomeに必要ファイルが残っていないことを本人が確認後、
   Mac所有者がシステム設定から削除
6. 既存ユーザーで作業した場合は、所有者確認後に`~/Developer/sizeyoho-work`だけを削除可能。
   Xcode、Homebrew、他project、共有cacheは削除しない
7. Keychainの証明書・秘密鍵やprovisioning profileは勝手に削除しない。削除が必要ならTeam名と
   対象を読み合わせ、Mac所有者とサイズ予報側アカウント所有者の同意後に限定して行う

夫のApple IDをサインアウトしたり、macOS・既存Xcode・動画編集toolを更新/削除したりしません。

## 公式要件

- [Apple upcoming requirements](https://developer.apple.com/news/upcoming-requirements/)
- [Xcode system requirements](https://developer.apple.com/xcode/system-requirements)
- [Screenshot specifications](https://developer.apple.com/help/app-store-connect/reference/app-information/screenshot-specifications)
- [Submit an in-app purchase](https://developer.apple.com/help/app-store-connect/manage-submissions-to-app-review/submit-an-in-app-purchase/)
- [TestFlight subscription testing](https://developer.apple.com/help/app-store-connect/test-a-beta-version/testing-subscriptions-and-in-app-purchases-in-testflight/)
- [Manage Sandbox Apple Account settings](https://developer.apple.com/help/app-store-connect/test-in-app-purchases/manage-sandbox-apple-account-settings/)
- [Enable Billing Grace Period](https://developer.apple.com/help/app-store-connect/manage-subscriptions/enable-billing-grace-period-for-auto-renewable-subscriptions/)
- [Google Mobile Ads iOS release notes](https://developers.google.com/admob/ios/rel-notes)

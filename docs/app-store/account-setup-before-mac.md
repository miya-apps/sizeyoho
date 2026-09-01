# Macを借りる前に本人が行うアカウント設定

これらはWindowsのブラウザでできます。認証情報をチャットへ貼らず、画面を1つずつ
確認します。契約、支払い、2FA、秘密鍵作成はユーザー本人だけが行います。

## 1. Apple Developer

1. サイズ予報のDeveloper Apple IDで[Apple Developer](https://developer.apple.com/account/)へサインイン
2. Program membershipがActiveか確認
3. Certificates, Identifiers & Profiles > Identifiers > `+`
4. App IDs > Appを選択
5. Descriptionを`サイズ予報`、Bundle IDをExplicitで`com.miyaapps.sizeyoho`
6. CapabilitiesでSign in with AppleとIn-App Purchaseを有効化
7. Register前の確認画面でTeamとBundle IDを再確認して本人が登録

Bundle IDが既に使用中、または別Teamにある場合は止めます。別IDを勝手に作らず、
コード、Firebase、AdMob、App Store Connectを全部そろえて変更する必要があります。

## 2. App Store Connect app record

1. [App Store Connect](https://appstoreconnect.apple.com/) > Apps > `+` > New App
2. Platforms: iOS
3. Name: サイズ予報
4. Primary Language: Japanese
5. Bundle ID: `com.miyaapps.sizeyoho`
6. SKU: `sizeyoho-ios`（内部管理値の案）
7. User Accessは必要最小限
8. Create

アプリ名が取得できない場合の代替名は現時点ではわかりません。ユーザー本人が名称を
決めるまで作成を止めます。

## 3. 有料契約

App Store ConnectのBusiness（またはAgreements, Tax, and Banking）で、Account Holderが
次を確認します。

- Paid Apps AgreementがActive
- 税務情報が完了
- 銀行口座が有効
- 連絡先情報の警告がない

入力内容・口座情報・本人確認資料は共有しません。

## 4. サブスクリプション商品

App record > Monetization > Subscriptionsで作成します。

1. Subscription Group: `サイズ予報 Pro`
2. 月額: Product ID `sizeyoho_pro_monthly`、期間1か月
3. 年額: Product ID `sizeyoho_pro_yearly`、期間1年
4. 2商品を同じgroup・同じlevelにする
5. 日本語display name/descriptionは[掲載文案](metadata-ja.md)を使用
6. 価格、販売地域、税categoryを本人が決定
7. Review InformationのscreenshotはMacのSandbox確認後に追加

Product IDは保存後に変更できません。大文字小文字とunderscoreを含め、入力前に
コードと読み合わせます。無料trialやintroductory offerは今回のコード・文案にないため、
本人が明示的に決めるまで設定しません。

Google PlayとApp Storeの購入権利を共通化するbackendはありません。このまま公開すると、
AndroidでPro購入済みの利用者もiPhoneでは別途App Store購入が必要です。この仕様と
利用者への明記を受け入れるか、別途backendを実装するかを本人が決めます。

Billing Grace PeriodはApp Store Connect > Subscriptionsで、有効/無効、日数、対象renewal、
Sandboxのみ/本番＋Sandboxを本人が決めます。無効ならGrace Period試験は対象外、
有効ならSandboxでProが維持されることを試験します。

### 4-A. Sandbox testerをWindowsで準備

App Store Connect > Users and Access > Sandboxで、実在の個人Apple IDと共用しない
Sandbox Apple Accountをシナリオ別に用意します。

| tester | 用途 | 事前設定 |
|---|---|---|
| A | 購入履歴なしの復元 | 新規、購入履歴なし |
| B | 月額購入・更新・失効 | 更新速度を記録 |
| C | 年額購入・再install・別端末復元 | 更新速度を記録 |
| D | interrupted purchase / Billing Retry / Grace Period | `Interrupt Purchases`とGraceの有効範囲を記録 |

Sandboxの既定値は1か月商品が5分、1年商品が1時間で更新されます。速度を変える場合は、
各testerで選んだ値と試験時刻を確認表に残します。Sandbox設定では自動更新が最大12回、
通常のTestFlightアカウントでは1日1回・最大6回という別の動作です。

[AppleのSandbox設定](https://developer.apple.com/help/app-store-connect/test-in-app-purchases/manage-sandbox-apple-account-settings/)と
[TestFlight課金テスト](https://developer.apple.com/help/app-store-connect/test-a-beta-version/testing-subscriptions-and-in-app-purchases-in-testflight/)を使います。
認証情報は共有しません。Sandboxのシナリオ制御でiPhoneのMedia & Purchasesから
サインアウトが必要な場合、他人のApple IDでは行わず、本人所有のテスト端末でのみ行います。

## 5. Firebase iOS app

1. [Firebase Console](https://console.firebase.google.com/)でproject `sizeyoho`
2. Project settings > General > Your apps > Add app > iOS
3. Apple bundle ID: `com.miyaapps.sizeyoho`
4. App nickname: `サイズ予報 iOS`（管理用の案）
5. App Store IDはrecord作成後にわかる場合だけ入力
6. Register app
7. `GoogleService-Info.plist`を本人の安全な場所へdownload

plistの次の値を、`config/ios.firebase.example.json`をコピーした
`config/ios.firebase.json`へ対応させます。

| plist key | JSON key |
|---|---|
| `API_KEY` | `FIREBASE_IOS_API_KEY` |
| `GOOGLE_APP_ID` | `FIREBASE_IOS_APP_ID` |
| `GCM_SENDER_ID` | `FIREBASE_MESSAGING_SENDER_ID` |
| `PROJECT_ID` | `FIREBASE_PROJECT_ID` |
| `STORAGE_BUCKET` | `FIREBASE_STORAGE_BUCKET` |
| `BUNDLE_ID` | `FIREBASE_IOS_BUNDLE_ID` |

JSONやplistの中身をチャットへ貼りません。`git check-ignore -v
config/ios.firebase.json`でignoreされることだけ確認します。

Firebase Console > Firestore Database > Rulesで、現在の本番rulesを保存し、repoの
`firestore.rules`と照合します。repo版はUID所有者限定に加え、アカウント削除markerの後は
別端末からの新規backup writeを拒否します。公開中Androidも同じbackendを使うため、
無断deployせず、Rules Playground/EmulatorとAndroid実機で既存user・初回userの保存/復元を
確認してから本人が反映します。反映前は複数端末同時利用時の完全削除を保証できないため、
iOS提出へ進みません。App Checkの本番状態はrepoからはわかりません。Consoleで有効/無効と
対象appを記録します。

## 6. Firebase Apple認証

1. Firebase Console > Authentication > Sign-in method
2. Apple providerを開いてEnable
3. 画面が要求するApple Team ID、Service ID、Key ID、private keyを、
   [Firebase公式手順](https://firebase.google.com/docs/auth/flutter/federated-auth)と
   [AppleのSign in with Apple設定](https://developer.apple.com/help/account/configure-app-capabilities/configure-sign-in-with-apple/)に従って本人が設定
4. Save

`.p8`を作成した場合は安全な保管場所へ置き、GitHub、project folder、チャットへ
入れません。画面が要求しない項目を推測で作りません。

## 7. AdMob

1. AdMob > Appsでサイズ予報のiOS appを開く
2. App IDが`ca-app-pub-7890458320134528~3308268731`と一致するか確認
3. Bundle IDが`com.miyaapps.sizeyoho`と一致するか確認
4. Banner ad unitが存在し、Unit IDが
   `ca-app-pub-7890458320134528/6216592970`と一致するか確認
5. Mediationを使っていないことを確認。使っている場合は追加SDK監査が必要なので停止
6. 販売storefrontだけでなく、利用者の現在地域と適用法域を前提にPrivacy & messagingを作成・公開
   - EEA/UK/Switzerlandを含む: European regulations
   - 対象となる米国州を含む: U.S. states/GPPまたはRDPを実態に合わせて判断
7. 今回はATT/IDFAを使わないため、IDFA explainer messageは作らない
8. Test devicesへ確認用iPhoneを登録する準備をする
9. Audience設定が「保護者向け」で、Kids/child-directedではない実態と一致するか確認

IDが違う場合は、正しい実在IDを確認してからコードを変更します。架空IDやAndroid IDを
入れません。

## 8. App Storeの販売・法務設定

App Store Connectで次をユーザー本人が決めます。DSAは販売地域に関係しますが、
広告同意は旅行者等も含む利用時の地域・法域で判定されるため、storefrontだけで対象外にしません。

- App price: 無料（アプリ本体。ProはIAP）
- Availability: 配信国・地域
- EUを含む場合: Digital Services Actのtrader statusと公開連絡先の検証
- Content Rights: アプリ内データ・画像・参照情報を配信する権利の質問へ実態どおり回答
- Apple Silicon MacでのiPhoneアプリ配信: 未テストなので有効にするか判断
- Apple Vision Pro互換配信: 未テストなので有効にするか判断
- 自動公開または手動公開

Apple Silicon Mac / visionOSへ出す場合は、その環境のUI・権限・課金を追加テストします。
テストしない場合はiPhone公開と同時に広げません。

## 9. 公開Webページ

1. このPRの`docs/privacy.html`を本番へdeploy
2. 公開ページの最終改定日が2026年9月1日で、広告、アプリ内削除、保管期間、
   第三者保護の本文が載っていることを確認
3. 次の5 URLがHTTPSで200応答し、空ページや認証画面でないことを確認
   - Marketing
   - Support / Contact
   - Privacy
   - Terms
   - Disclaimer
   監査時点でTermsは自動更新、解約、復元、返金を、Disclaimerは予測・医療免責を記載済みです。
   本番提出直前に内容も再確認し、Store間のPro非移行をTerms/サポートへ追記します。
4. App Store価格決定後、サイトの固定料金がGoogle Playだけの価格か、両store共通かを
   明記し、購入画面の価格と矛盾しないよう更新
5. 「App Store準備中」は提出中まで残してよい。承認・公開URL確定後にMarketingページの
   入手buttonと、Contactページのリリース通知文・CTAを公開状態へ更新

サイト更新はPRをmergeしただけで反映されるか、GitHub Pagesの公開元設定を本人が確認します。
公開URLへ反映される前にApp Store ConnectへPrivacy URLを確定しません。

## 10. Windowsでの最終検査

普段のFlutter環境でproject rootから実行します。

```powershell
powershell -ExecutionPolicy Bypass -File tool/check_ios_release_config.ps1
flutter pub get
flutter analyze
flutter test
flutter build apk --debug
```

debug APKはローカル回帰確認だけに使います。AAB作成・Play Console upload・versionCode変更は
行いません。Android端末またはemulatorで、起動、広告、月額/年額購入、復元、Google
ログイン、クラウドバックアップ、PDF/JSONを確認します。

その後、作業branchがGitHubにpush済みで、Macから取得できることをGitHub画面で確認します。
AndroidのGoogleクラウドからiPhoneへは直接復元できずJSON移行になる仕様差も、本人が
受け入れるか、iOS Googleログインを追加実装するかをここで決めます。
Google PlayとApp StoreのPro購入が相互移行しない仕様も、同じく本人が承認します。

AndroidのGoogleログインは公式推奨の`google_sign_in`経路ではない既存実装です。
今回はAndroidを勝手に変更せず実機回帰で成否を確認し、失敗する場合は別作業として承認を取ります。

`docs/store-assets/export-all.bat`も実行し、Git対象外の`store-submission/ios-6.9`に
1290×2796の6枚が生成されることを確認します。追跡済みWeb用PNG/WebPは縮小済みの旧画像で、
App Store用原寸を上書きしません。Web画像のcopyも変える場合は別途再生成します。

## 11. 完了時に記録するもの

秘密値ではなく、次のYes/Noだけを作業メモへ残します。

- Apple membership Active: Yes/No
- Bundle ID registered: Yes/No
- App record created: Yes/No
- Paid agreement/tax/bank Active: Yes/No
- Monthly/yearly products created: Yes/No
- Cross-store Pro entitlement limitation accepted (or backend implemented): Yes/No
- Billing Grace Period policy decided: Yes/No
- Sandbox scenario testers ready: Yes/No
- Firebase iOS app registered: Yes/No
- Apple provider enabled: Yes/No
- Local Firebase JSON ready and ignored: Yes/No
- Production Firestore deletion-marker rules deployed after Android regression: Yes/No
- Firebase App Check state recorded: Yes/No
- AdMob IDs matched: Yes/No
- Storefronts decided: Yes/No
- Applicable regional consent messages published: Yes/No
- GPP/RDP policy and implementation checked, or not applicable with reason: Yes/No
- AdMob audience setting matched: Yes/No
- DSA trader status completed or not applicable: Yes/No
- Privacy source deployed and five live URLs checked: Yes/No
- Pre-submission marketing price wording reconciled: Yes/No
- Terms/support explain cross-store Pro non-transfer: Yes/No
- App Store 6.9-inch draft images exported: Yes/No
- iOS Firebase preflight passed: Yes/No
- Flutter analyze/test/debug APK passed: Yes/No
- Android runtime regression passed: Yes/No
- Remote branch available: Yes/No
- Apple-only cloud + JSON migration accepted (or Google login implemented): Yes/No

すべてYesになった時点が「ここからMacBookを借りる」タイミングです。

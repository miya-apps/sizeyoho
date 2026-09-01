# App Privacy・Privacy Manifest回答案

最終更新: 2026-09-01

これは入力前の根拠表です。App Store Connectへまだ確定回答しません。Macで生成した
Xcode Privacy Report、実際に解決されたSDK、AdMob管理画面の設定を突き合わせてから
ユーザー本人が回答します。

## アプリ自身が扱うデータ

| データ | 端末外へ送る条件 | 利用目的 | ユーザーとの関連 | 追跡 |
|---|---|---|---|---|
| 子どもの名前 | Proでクラウドバックアップ（自動または今すぐ）を実行した時だけ。写真は除外 | App Functionality（バックアップ・復元） | Firebase User IDにlinked | しない |
| 生年月日/性別/足長/父母の身長/靴購入記録/おむつ設定/記録/メモ | 同上 | App Functionality（バックアップ・復元） | linked | しない |
| 身長/体重/足長 | 同上 | App Functionality | linked | しない |
| 写真 | Firebase自動backupへは送らない。利用者操作の手動backup/保存/共有は選択先へ転送 | App Functionality | 開発者による収集なし。Apple定義は最終確認 | しない |
| メールアドレス | クラウド用Appleサインイン時 | App Functionality（所有者識別） | linked | しない |
| Firebase User ID | クラウド用サインイン時。account削除後も別端末の遅延write拒否用markerとして保持 | App Functionality / Security | linked | しない |
| 問い合わせ本文・連絡先 | 利用者が外部Googleフォームを送信した時 | App Functionality / Customer Support | linkedになり得る | しない |
| 購入権利 | StoreKitが端末上で処理。開発者サーバーへ送らない | Pro権利確認 | アプリ独自収集なし | しない |

App Store Connectの型としては、クラウド利用者について次が候補です。

- Contact Info > Email Address
- Contact Info > Name（子どもの名前。特定の型を尋ねているため候補）
- Identifiers > User ID
- Health & Fitness > Health（身長・体重等。Appleの最新定義を入力画面で再確認）
- User Content > Other User Content（生年月日、性別、足長、メモ等）
- Contact Info / User Content（問い合わせをアプリ経由の収集と扱う場合）

写真はPhoto Library権限を使いますが、Firebaseへ送信しません。「権限を使う」ことと
「Appleの定義でデータを収集する」ことは同じではありません。

account削除時は子どもの記録、メールアドレス、backup chunk、Firebase Auth accountを削除し、
FirestoreにはUIDをdocument IDとする`deleting`/削除日時markerだけを残します。このmarkerの
Security目的・保持方針を、App Privacy最終回答と公開Privacy Policyの双方へ含めます。

## Firebase Auth / Firestore

Firebase公式のApple向け開示資料で、今回組み込むSDKについて次を確認しました。

| SDK | 公式に記載された挙動 | このアプリでの確認事項 |
|---|---|---|
| Firebase Authentication | 認証用identifierを常時生成・保存。既定でFirebase user agentを収集。連携providerからemail等を取得し得る | User ID・Email Addressはlinked / App Functionality候補。Appleログイン実機結果と照合 |
| Cloud Firestore | data collection有効時にFirebase user agentを既定収集 | device・OS・bundle ID・developer platformで構成され、Googleはuser/device identifierにlinkしないと説明 |
| Firebase user agent | device、OS、app bundle ID、developer platform | App Store Connectで該当するdata typeは最終入力画面とPrivacy Reportで確定 |

Firebase Authenticationは認証時のセキュリティ・不正防止にuser-agent文字列とIP addressも
利用し、IPログを数週間保持するとGoogleが説明しています。これらを含む最終回答は、
Macで解決されたFirebase target一覧とXcode Privacy Reportを見て確定します。

## Google Mobile Ads / UMP

リポジトリのiOSコードは次の方針です。

- ATTを呼ばない
- `NSUserTrackingUsageDescription`を置かない
- IDFAを使わない
- 対象地域ではUMP同意の完了後まで広告リクエストしない
- UMPが要求する場合だけ「広告のプライバシー設定」を表示
- 広告コンテンツ上限をGに設定

Google公式GMA/UMPバイナリのPrivacy Manifestが申告する候補は次です。実際の
App Store回答は、Macで解決されたバージョンのPrivacy Reportで確定します。

| データ | Linked | SDK manifest上のTracking | 主な目的 |
|---|---:|---:|---|
| Device ID | はい | はい | Third-Party Advertising、Developer Advertising、Analytics |
| Coarse Location | はい | いいえ | 広告、Analytics、App Functionality |
| Advertising Data | はい | いいえ | 広告、Analytics |
| Product Interaction | はい | いいえ | 広告、Analytics、App Functionality |
| Performance Data | はい（Googleはuser-associatedと説明） | Privacy Reportで確認 | 広告、Analytics、App Functionality |
| Crash Data | いいえ | いいえ | Analytics |
| Other Diagnostic Data | いいえ | いいえ | 広告、Analytics |

重要: SDKの汎用manifestはDevice IDをtrackingとして含みますが、本アプリはATTを
要求せずIDFAを使わない構成です。この差を推測で処理しません。提出前に以下を完了し、
「Trackingなし」と実態が一致することを確認します。

1. AdMobでiOSアプリ、Unit ID、mediation未使用、Privacy & messagingを確認
2. European regulations messageを公開
3. storefrontだけで対象外とせず、利用者の現在地域と適用法域を基準に、該当する
   U.S. states message、GPP、RDPの方針と実装を判断
4. AdMobのaudienceを保護者向け（Kids/child-directedではない）実態に合わせる
5. 実機でATTダイアログが出ず、必要地域ではUMPが先に出ることを確認
6. Xcode Privacy Reportで全SDKの集約値を確認
7. Googleの最新Data DisclosureページとApp Store Connectの定義を照合

一致を確認できない場合は提出を止め、ATTを実装してTrackingを申告するか、広告構成を
追跡しないものへ変更します。現時点でATTの説明文や架空の同意動線は追加しません。

## Privacy Manifest / Required Reason API

- 2024-05-01以降、対象APIには承認理由が必要
- Apple指定の主要third-party SDKは署名とprivacy manifestが必要
- 現在のアプリ独自SwiftコードではRequired Reason APIの直接呼び出しを確認していない
- Flutter、Firebase、Google Mobile Ads、shared_preferences等のmanifestは、Macで
  SwiftPMを解決しArchiveした時点の実ファイルを確認する
- アプリ独自の`PrivacyInfo.xcprivacy`へ理由コードを推測で追加していない

Google Mobile Adsの現行候補にはSystem Boot Time `35F9.1`、UserDefaults `CA92.1`、
Disk Space `E174.1`、UMPにはUserDefaults `CA92.1`が含まれます。これはSDK自身の
manifestであり、Macで解決された版が同じとはまだ確定していません。

## Sign in with Apple

iOSではクラウドバックアップ用にAppleログインだけを表示します。Xcode entitlementは
準備済みです。Apple DeveloperでApp ID capabilityを有効化し、Firebase Authentication
でApple providerを構成する必要があります。アプリ内削除は、削除直前に再認証し、
authorization codeをFirebaseへ渡してApple tokenをrevokeしてから、Firestoreと
Firebase Authアカウントを削除します。

## Export Compliance

アプリ独自の暗号実装は確認できず、HTTPS/TLS、Firebase、StoreKit等の標準暗号を
利用しています。ただしApp Store Connectの質問への最終回答は、表示される最新質問と
利用SDKを確認するまでわかりません。`ITSAppUsesNonExemptEncryption=NO`は推測で
Info.plistへ固定していません。

標準暗号のみで免除扱いになる可能性があります（推測です）。Upload時の質問に実態どおり
回答し、App Store Connectが書類を求めた場合だけ提出します。

## 公式資料

- [Apple: App privacy details](https://developer.apple.com/app-store/app-privacy-details/)
- [Apple: Manage app privacy](https://developer.apple.com/help/app-store-connect/manage-app-information/manage-app-privacy)
- [Apple: Privacy manifest files](https://developer.apple.com/documentation/bundleresources/privacy-manifest-files)
- [Apple: Required Reason API](https://developer.apple.com/documentation/bundleresources/describing-use-of-required-reason-api)
- [Apple: Third-party SDK requirements](https://developer.apple.com/support/third-party-SDK-requirements/)
- [Apple: User privacy and data use / ATT](https://developer.apple.com/app-store/user-privacy-and-data-use/)
- [Google: UMP for Flutter](https://developers.google.com/admob/flutter/privacy)
- [Google: IDFA support](https://developers.google.com/admob/flutter/privacy/idfa)
- [Firebase: Federated auth for Flutter](https://firebase.google.com/docs/auth/flutter/federated-auth)
- [Firebase: Apple App Store data collection](https://firebase.google.com/docs/ios/app-store-data-collection)
- [Firebase: Privacy and security](https://firebase.google.com/support/privacy)
- [Google Mobile Ads: App Store data disclosure](https://developers.google.com/admob/ios/privacy/data-disclosure)
- [Apple: Export compliance](https://developer.apple.com/help/app-store-connect/manage-app-information/overview-of-export-compliance)

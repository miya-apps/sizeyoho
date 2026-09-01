# Apple提出要件確認（2026-09-01時点）

Apple公式情報を優先して確認した結果です。提出直前にも同じURLで再確認します。

| 項目 | 現行要件 | サイズ予報への対応 |
|---|---|---|
| Xcode / SDK | 2026-04-28以降はXcode 26以降・iOS 26 SDKでupload | GMAも考慮しXcode 26.2以上を使用 |
| iOS minimum | Appが決定 | projectをiOS 15.0へ統一 |
| App record | Bundle ID、SKU、platform、name等が必要 | `com.miyaapps.sizeyoho`を本人が登録 |
| Privacy Policy URL | App Privacyで必要 | URLは公開済みだが本番は旧文面。ローカル更新をdeployし200/内容確認するまでP0 |
| Support URL | metadataで必要 | 公開contact URLあり |
| App Privacy | 開発者とthird-party partnerの収集を回答 | Mac Privacy Report後に確定 |
| Privacy Manifest | 対象SDK/APIのmanifestとapproved reasonが必要 | SDK集約をArchiveで検査。理由を推測追加しない |
| ATT | 他社app/siteを横断して追跡する場合に許可が必要 | ATTなし・IDFA不使用で準備。広告実態と最終照合 |
| Sign in with Apple | 対象となるthird-party/social loginがある場合 | iOSはAppleのみ。capability・削除/revoke実装済み |
| IAP | デジタル機能はApple IAP、復元、subscription情報が必要 | 月/年2商品、StoreKit 2、復元、管理導線を準備 |
| Export Compliance | encryption利用を質問票で回答 | standard TLS中心。最終回答前なのでplistへ固定しない |
| 年齢rating | 最新質問票に回答しApp Store Connectが算出 | 最終値はまだわからない。Kids Categoryは選ばない |
| screenshot | 1セット1〜10枚。iPhone 6.9"の対応寸法を使用可能 | 1290×2796の6枚台紙あり、iOS画面はMacで採取 |
| Review情報 | 連絡先、notes、必要ならlogin | coreはlogin不要。Review Notes案あり |
| Availability | 配信国・地域と無料/有料を設定 | 本体は無料案。配信地域は本人決定待ち |
| EU DSA | EUでtraderとして配信する場合、連絡先を検証・表示 | EU配信有無とtrader statusは未確認 |
| Content Rights | third-party contentの権利を回答 | 公的成長データ・商品参照・icon licenseを本人が最終確認 |
| Mac / Vision Pro互換配信 | iPhone appの互換配信を個別にopt out可能 | 未テスト。iPhone以外へ同時配信するか本人判断 |

## Screenshot寸法

現在AppleがiPhone 6.9インチ枠で受け付ける寸法には、縦向きで次が含まれます。

- 1260 × 2736
- 1290 × 2796
- 1320 × 2868

6.9インチ用を入れない場合は6.5インチ用が必須になる条件があります。サイズ予報は
iPhone-onlyとし、既存台紙の1290×2796を使うため、この分岐を避けます。iPad native
targetを外したのでiPad screenshotは不要です。

## Metadata上限

- App name: 2〜30文字
- Subtitle: 30文字以内
- Description: 4,000文字以内
- Keywords: 100 bytes以内
- Promotional text: 170文字以内

文案は[metadata-ja.md](metadata-ja.md)にあります。

## 自動更新サブスクリプション

- 月額と年額を同じsubscription group・同じlevelへ登録
- 期間、価格、display name、description、販売地域を設定
- 購入画面で期間、価格、自動更新、規約、Privacyを表示
- Restore Purchases導線を提供
- 初回IAPはapp versionと一緒にReviewへ提出
- Paid Apps Agreement、税務、銀行情報が有効であること
- Review用screenshotを商品ごとに用意

Appleが自前serverを審査の絶対条件としているわけではありません。本実装はiOS 15+
のStoreKit 2 `Transaction.currentEntitlements`が返す検証済み現在権利を端末上で利用し、
期限切れ・返金・取消を反映します。App Store Server API/Notificationsは、複数platformの
権利統合やserver側運用を行う将来の強化候補です。

## 公式リンク

- [Upcoming requirements](https://developer.apple.com/news/upcoming-requirements/)
- [Xcode system requirements](https://developer.apple.com/xcode/system-requirements)
- [Create an app record](https://developer.apple.com/help/app-store-connect/create-an-app-record/add-a-new-app)
- [App Review Guidelines](https://developer.apple.com/app-store/review/guidelines/)
- [App privacy details](https://developer.apple.com/app-store/app-privacy-details/)
- [Manage app privacy](https://developer.apple.com/help/app-store-connect/manage-app-information/manage-app-privacy)
- [Privacy manifest files](https://developer.apple.com/documentation/bundleresources/privacy-manifest-files)
- [Required Reason API](https://developer.apple.com/documentation/bundleresources/describing-use-of-required-reason-api)
- [Third-party SDK requirements](https://developer.apple.com/support/third-party-SDK-requirements/)
- [ATT / user privacy and data use](https://developer.apple.com/app-store/user-privacy-and-data-use/)
- [Age rating](https://developer.apple.com/help/app-store-connect/manage-app-information/set-an-app-age-rating)
- [Age rating definitions](https://developer.apple.com/help/app-store-connect/reference/app-information/age-ratings-values-and-definitions)
- [Screenshot specifications](https://developer.apple.com/help/app-store-connect/reference/app-information/screenshot-specifications)
- [Upload screenshots](https://developer.apple.com/help/app-store-connect/manage-app-information/upload-app-previews-and-screenshots)
- [Export compliance](https://developer.apple.com/help/app-store-connect/manage-app-information/overview-of-export-compliance)
- [Auto-renewable subscriptions](https://developer.apple.com/help/app-store-connect/manage-subscriptions/offer-auto-renewable-subscriptions/)
- [Submit an IAP](https://developer.apple.com/help/app-store-connect/manage-submissions-to-app-review/submit-an-in-app-purchase/)
- [App availability](https://developer.apple.com/help/app-store-connect/manage-your-apps-availability/manage-availability-for-your-app-on-the-app-store/)
- [EU DSA trader requirements](https://developer.apple.com/help/app-store-connect/manage-compliance-information/manage-european-union-digital-services-act-trader-requirements/)
- [App information / Content Rights](https://developer.apple.com/help/app-store-connect/reference/app-information/app-information/)
- [iPhone apps on Apple silicon Mac](https://developer.apple.com/help/app-store-connect/manage-your-apps-availability/manage-availability-of-iphone-and-ipad-apps-on-macs-with-apple-silicon/)
- [iPhone apps on Apple Vision Pro](https://developer.apple.com/help/app-store-connect/manage-your-apps-availability/manage-availability-of-iphone-and-ipad-apps-on-apple-vision-pro/)

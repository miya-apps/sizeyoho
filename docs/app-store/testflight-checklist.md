# TestFlight実機確認表

対象: iPhone / version 1.0.0 (build `N`：実際のupload値)
実施日・端末・iOS版: 実施時に記入

`結果`は `OK / NG / 未実施 / 対象外` のどれかで記入します。NGが1件でも残る場合は
App Store審査へ提出しません。スクリーンショットに実在する子どもの個人情報を使いません。

## 課金testerの事前割当

| tester | シナリオ | 記録する設定 |
|---|---|---|
| A | 購入履歴なしの復元 | 国/地域、履歴なし |
| B | 月額購入、更新、失効 | 更新速度、開始時刻 |
| C | 年額購入、再install/別端末復元 | 更新速度、開始時刻 |
| D | interrupted purchase、Billing Retry、Grace Period | Interrupt/Graceの有効範囲、更新速度 |

Sandbox Apple Accountの既定値は1か月商品が5分、1年商品が1時間で更新され、最大12回更新されます。
通常のTestFlightアカウントは1日1回・最大6回です。どちらで試すかを行ごとに記録し、
夫や他人の本番Apple IDをサインアウトしません。

## インストール・基本動作

| # | 確認 | 期待結果 | 結果・メモ |
|---:|---|---|---|
| 1 | TestFlightから新規install | install・初回起動が成功 | |
| 2 | 初回起動 | crash、長い白画面、debug表示なし | |
| 3 | 利用規約/Privacy/免責/license/商品参照 | HTTPSの正しいページが開く | |
| 4 | 問い合わせ | 正しいsupport/contactページが開く | |
| 5 | 画面端swipe back | push画面から自然に戻れる | |
| 6 | Safe Area | Dynamic Island/Home Indicatorと重ならない | |
| 7 | 小型・大型iPhone | 切れ、overflow、操作不能なし | |

## 子ども・成長記録

| # | 確認 | 期待結果 | 結果・メモ |
|---:|---|---|---|
| 8 | 子どもを新規登録 | 名前、生年月日、性別等を保存 | |
| 9 | 2人目を追加・切替 | 最大数内で正しく切替 | |
| 10 | 身長・体重を追加 | 履歴とグラフへ反映 | |
| 11 | 記録を編集・削除 | 対象日だけ正しく更新 | |
| 12 | 成長曲線 | 身長・体重、月齢、凡例が正しい | |
| 13 | SDスコア | 表示切替・値・スクロールが動作 | |
| 14 | アプリ再起動 | 登録・記録・選択中の子が保持 | |
| 15 | iPhone再起動 | データが保持 | |

## サイズ予報

| # | 確認 | 期待結果 | 結果・メモ |
|---:|---|---|---|
| 16 | 洋服サイズ | 現在/季節別サイズが表示 | |
| 17 | 靴サイズ | 足長登録、購入記録、次サイズ表示 | |
| 18 | おむつサイズ | 設定ON時に目安が表示 | |
| 19 | Pro gate | 無料時は先読み/画像保存が正しく制限 | |

## 写真・PDF・ファイル

| # | 確認 | 期待結果 | 結果・メモ |
|---:|---|---|---|
| 20 | 写真を選択 | 権限文が正しく、選択写真が表示 | |
| 21 | カメラ撮影 | 権限文が正しく、撮影写真が表示 | |
| 22 | グラフ画像保存 | Pro時に写真へ保存 | |
| 23 | 画像共有 | iOS share sheetが開く | |
| 24 | PDF生成 | 日本語、改ページ、値が正しく表示 | |
| 25 | PDF保存 | Filesの選択先へ保存、cancelはエラー扱いしない | |
| 26 | JSON書き出し | Filesの選択先へ保存 | |
| 27 | JSON読込 | iCloud Drive/このiPhone内から選択・復元 | |
| 28 | 日本語名の復元 | 文字化けしない | |

## 広告・同意

| # | 確認 | 期待結果 | 結果・メモ |
|---:|---|---|---|
| 29 | EEA consent test | UMP完了前に広告requestなし | |
| 30 | UMP consent | 必要地域で同意画面が表示 | |
| 31 | Privacy options | 必要時だけ設定に入口が出て再表示可能 | |
| 31-A | U.S. states message（適用時） | 対象法域で公開済みmessageが表示され、選択が反映 | |
| 31-B | GPP/RDP（適用時） | 決定済みの方針とAdMob設定・アプリ挙動が一致。対象外なら根拠を記録 | |
| 32 | ATT | ATTダイアログが出ない | |
| 33 | 無料版banner | test deviceでTest Ad表示、幅・余白が正常 | |
| 34 | Pro版 | 広告が消え、再起動直後もrequestしない | |
| 35 | Pro失効 | 権利更新後にbannerが再表示 | |

TestFlightはRelease buildのため本番Unit IDを使います。AdMobでテスト端末登録し、
「Test Ad」を確認するまで広告をタップしません。

EEAまたは対象となる米国州の外から試す場合、TestFlightだけではdebug geographyを強制できません。MacのDebug buildで
Google公式手順の`ConsentDebugSettings`とテスト端末IDを一時設定して確認し、その変更を
commit/Releaseへ残さないか、対象法域に所在するテスターでTestFlight確認します。

## App Store課金

| # | 確認 | 期待結果 | 結果・メモ |
|---:|---|---|---|
| 36 | 商品読込 | 月額・年額の現地通貨価格が表示 | |
| 37 | 月額購入 | 成功後Proが有効、transaction完了 | |
| 38 | 年額購入 | 成功後Proが有効、transaction完了 | |
| 38-A | 月額⇄年額の切替 | 同じsubscription group/levelのStoreKit挙動と次回更新日がApp Store表示どおり | |
| 39 | 購入cancel | Proにならず、適切な通知 | |
| 40 | 購入pending/error | 二重購入せず、状態が説明される | |
| 41 | 復元 | 再install/別端末で有効権利が復元 | |
| 42 | 購入なしで復元 | 「有効な購入なし」と表示、Proにならない | |
| 43 | subscription更新/Grace Period | Grace有効時は猶予中もPro維持。無効方針なら対象外 | |
| 44 | subscription失効 | `currentEntitlements`から外れPro解除 | |
| 45 | 返金・取消 | Pro解除 | |
| 46 | 定期購入を管理 | App Storeのsubscription管理が開く | |

通常のTestFlightは1日1回・最大6回のため、素のままでは失効まで最長約1週間かかります。
短時間でrenewal/retry/graceを確認するときは、上記のSandbox testerと更新速度を使います。

## Appleログイン・クラウド

| # | 確認 | 期待結果 | 結果・メモ |
|---:|---|---|---|
| 47 | Appleでサインイン | buttonのlogo・文言・配色・余白が最新Apple HIGに沿い、Firebase userが作成される | |
| 48 | 今すぐbackup | 写真を除く記録が保存 | |
| 49 | 自動backup | 記録変更後に日時更新 | |
| 49-A | 自動backupを直後にOFF | 予約済みデータがFirebaseへ送信されない | |
| 49-B | 編集直後にsign out/account切替 | 旧accountの子どもデータが新accountへ保存されない | |
| 49-C | backup中に通信を中断 | 直前に成功したgenerationは復元可能で、新旧chunkが混ざらない | |
| 50 | クラウド復元 | 別installで記録復元、写真なし | |
| 51 | サインアウト | 端末データは残り、自動backup停止 | |
| 52 | アカウント削除cancel | データを消さず戻る | |
| 53 | アカウント削除 | 再認証後、backup/Auth/Apple tokenを削除し、個人内容のない削除markerだけ残る | |
| 53-A | 別端末から削除中write | 本番Firestore Rulesが新しいchunk/meta writeを拒否 | |
| 54 | 削除後再起動 | 端末記録は残り、クラウドuserは未login | |

## Privacy・審査資料

| # | 確認 | 期待結果 | 結果・メモ |
|---:|---|---|---|
| 55 | Privacy Report | App Privacy回答と一致 | |
| 56 | Required Reason API | 未説明APIなし | |
| 57 | 署名/entitlements | Apple login/IAPだけ、不要権限なし | |
| 58 | アイコン | 1024px、透明なし、端末表示正常 | |
| 59 | screenshot 6枚 | iOS実画面、個人情報なし、最新UIと一致 | |
| 60 | version/build | 1.0.0 (`N`)がArchive、upload、App Store Connectで一致 | |

## 審査提出ゲート

- [ ] 確認表の全項目がOKまたは理由のある対象外
- [ ] P0 blockerが0件
- [ ] 月額・年額IAPをversionへ紐付け済み
- [ ] App PrivacyとPrivacy Policyが一致
- [ ] support/privacy URLが公開状態で200応答
- [ ] Review Notesと連絡先を入力済み
- [ ] Android Play Consoleへ変更を加えていない

課金の根拠: [Apple Sandbox設定](https://developer.apple.com/help/app-store-connect/test-in-app-purchases/manage-sandbox-apple-account-settings/)、
[TestFlightの課金テスト](https://developer.apple.com/help/app-store-connect/test-a-beta-version/testing-subscriptions-and-in-app-purchases-in-testflight/)、
[Billing Grace Period](https://developer.apple.com/help/app-store-connect/manage-subscriptions/enable-billing-grace-period-for-auto-renewable-subscriptions/)

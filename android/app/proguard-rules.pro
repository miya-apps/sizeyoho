# リリースビルド（R8）でのコード削除による起動クラッシュ対策。
#
# google_mobile_ads が内部で使う androidx.work（WorkManager）は、
# Room の生成クラス WorkDatabase_Impl をリフレクションで探すため、
# R8 が「未使用」と判断して削除すると起動直後に
# "Failed to create an instance of androidx.work.impl.WorkDatabase"
# で落ちる。androidx.work 一式を残して防ぐ。
-keep class androidx.work.** { *; }

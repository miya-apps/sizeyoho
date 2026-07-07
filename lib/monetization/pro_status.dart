import 'package:flutter/foundation.dart';
import 'package:shared_preferences/shared_preferences.dart';

/// Pro 版（有料）の有効状態。
///
/// Pro 版では「オンライン自動バックアップ」と「広告非表示」を提供する予定。
/// 現時点では課金基盤が未導入のため常に false だが、広告表示や
/// 自動バックアップの分岐はこのフラグを参照して実装しておくことで、
/// 課金（ストア内購入）導入時にここを切り替えるだけで機能が有効になる。
class ProStatus {
  ProStatus._();

  static const String _kKey = 'pro_active_v1';

  /// Pro 版が有効なら true。UI は ValueListenableBuilder で監視できる。
  static final ValueNotifier<bool> isPro = ValueNotifier<bool>(false);

  /// 保存済みの状態を読み込む（起動時に一度呼ぶ）。
  static Future<void> load() async {
    final prefs = await SharedPreferences.getInstance();
    isPro.value = prefs.getBool(_kKey) ?? false;
  }

  /// 課金処理の成功/復元時に呼ぶ（現時点では未使用）。
  static Future<void> setActive(bool active) async {
    isPro.value = active;
    final prefs = await SharedPreferences.getInstance();
    await prefs.setBool(_kKey, active);
  }
}

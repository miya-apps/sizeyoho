import 'package:flutter/foundation.dart';
import 'package:shared_preferences/shared_preferences.dart';

/// Pro 版（有料）の有効状態。
///
/// Pro 版は「サイズの先読み予報」「オンライン自動バックアップ」
/// 「広告非表示」を提供する。PurchaseManager がストア購入・復元の
/// 成功時に [setActive] を呼び、UI はこのフラグを監視して切り替わる。
/// 開発ビルドとWebプレビューでは設定画面のスイッチでも切り替えられる。
class ProStatus {
  ProStatus._();

  static const String _kKey = 'pro_active_v1';
  static bool _persistenceDirty = false;

  /// Pro 版が有効なら true。UI は ValueListenableBuilder で監視できる。
  static final ValueNotifier<bool> isPro = ValueNotifier<bool>(false);

  /// 保存済みの状態を読み込む（起動時に一度呼ぶ）。
  static Future<void> load() async {
    final prefs = await SharedPreferences.getInstance();
    isPro.value = prefs.getBool(_kKey) ?? false;
    _persistenceDirty = false;
  }

  /// 課金処理、復元、StoreKitの現在権利確認から呼ぶ。
  static Future<void> setActive(bool active) async {
    if (isPro.value == active && !_persistenceDirty) return;
    isPro.value = active;
    try {
      final prefs = await SharedPreferences.getInstance();
      final saved = await prefs.setBool(_kKey, active);
      if (!saved) throw StateError('Pro status was not persisted');
      _persistenceDirty = false;
    } catch (_) {
      // 次回のStoreKit照会で同じ値でも保存を再試行する。
      _persistenceDirty = true;
      rethrow;
    }
  }
}

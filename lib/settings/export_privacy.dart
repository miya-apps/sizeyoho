import 'package:flutter/foundation.dart';
import 'package:shared_preferences/shared_preferences.dart';

import '../models/child_profile.dart';

/// 書き出し時のプライバシー設定。
///
/// ONにすると、受診レポート（PDF）とサイズガイド画像に載せる名前を
/// 「第一子」「第二子」…の匿名表記に置き換える（アプリ内の表示は実名のまま）。
/// 出生順は登録済みのお子様の生年月日から自動で決まるので、別途の設定は不要。
class ExportPrivacy {
  ExportPrivacy._();

  static const String _kKey = 'export_mask_names_v1';

  /// 書き出し時に名前を伏せるなら true。
  static final ValueNotifier<bool> maskNames = ValueNotifier<bool>(false);

  /// 保存済みの状態を読み込む（起動時に一度呼ぶ）。
  static Future<void> load() async {
    final prefs = await SharedPreferences.getInstance();
    maskNames.value = prefs.getBool(_kKey) ?? false;
  }

  static Future<void> setEnabled(bool enabled) async {
    maskNames.value = enabled;
    final prefs = await SharedPreferences.getInstance();
    await prefs.setBool(_kKey, enabled);
  }

  static const List<String> _ordinals = [
    '第一子', '第二子', '第三子', '第四子', '第五子',
    '第六子', '第七子', '第八子', '第九子', '第十子',
  ];

  /// 書き出しに使う表示名。設定がOFFなら実名、ONなら出生順の匿名表記。
  /// 出生順は [all]（登録済みの全お子様）の生年月日の早い順。
  static String displayNameFor(ChildProfile child, List<ChildProfile> all) {
    if (!maskNames.value) return child.displayName;
    final sorted = [...all]..sort((a, b) => a.birthDate.compareTo(b.birthDate));
    var index = sorted.indexWhere((c) => c.id == child.id);
    if (index < 0) index = 0;
    return index < _ordinals.length ? _ordinals[index] : '第${index + 1}子';
  }
}

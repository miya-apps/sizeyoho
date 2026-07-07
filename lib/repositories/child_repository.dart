import 'dart:convert';

import 'package:shared_preferences/shared_preferences.dart';

import '../models/child_profile.dart';

/// お子様データの読み書きを抽象化するインターフェース
abstract class ChildRepository {
  Future<List<ChildProfile>> loadChildren();
  Future<void> saveChildren(List<ChildProfile> children);
}

/// 無料会員向け：スマホ本体（SharedPreferences）に保存する実装クラス
class LocalChildRepository implements ChildRepository {
  static const _storageKey = 'saved_children_data';

  @override
  Future<List<ChildProfile>> loadChildren() async {
    final prefs = await SharedPreferences.getInstance();
    final jsonStr = prefs.getString(_storageKey);
    if (jsonStr == null || jsonStr.isEmpty) return [];

    final decoded = jsonDecode(jsonStr);
    if (decoded is! List<dynamic>) return [];

    return decoded
        .map((e) => ChildProfile.fromJson(e as Map<String, dynamic>))
        .toList();
  }

  @override
  Future<void> saveChildren(List<ChildProfile> children) async {
    final prefs = await SharedPreferences.getInstance();
    final jsonStr = jsonEncode(children.map((c) => c.toJson()).toList());
    await prefs.setString(_storageKey, jsonStr);
  }
}

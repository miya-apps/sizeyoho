/// バックアップファイル（JSON）の書き出し・読み込み。
///
/// 全お子様のデータ（プロフィール・写真・成長記録・靴の記録）を
/// 1つのファイルにまとめる。無料版の機種変更時の手動引き継ぎと、
/// 将来の Pro 版オンライン自動バックアップの両方でこの形式を使う。
///
/// 形式:
/// ```json
/// {
///   "app": "grow_app",
///   "format": 1,
///   "exportedAt": "2026-07-05T15:00:00.000",
///   "children": [ ...ChildProfile.toJson()... ]
/// }
/// ```
library;

import 'dart:convert';

import '../models/child_profile.dart';

/// 現在のバックアップ形式バージョン。
/// 互換性が壊れる変更をしたらインクリメントする。
const int backupFormatVersion = 1;

/// バックアップの読み込みに失敗したときの、利用者向けメッセージ付き例外。
class BackupDecodeException implements Exception {
  const BackupDecodeException(this.message);

  final String message;

  @override
  String toString() => 'BackupDecodeException: $message';
}

/// 全お子様データをバックアップ JSON 文字列にする。
String encodeBackupJson(List<ChildProfile> children) {
  return jsonEncode({
    'app': 'grow_app',
    'format': backupFormatVersion,
    'exportedAt': DateTime.now().toIso8601String(),
    'children': children.map((c) => c.toJson()).toList(),
  });
}

/// バックアップ JSON 文字列からお子様データを復元する。
/// 形式が不正な場合は [BackupDecodeException] を投げる。
List<ChildProfile> decodeBackupJson(String source) {
  Object? decoded;
  try {
    decoded = jsonDecode(source);
  } on FormatException {
    throw const BackupDecodeException(
      'ファイルを読み取れませんでした。バックアップファイル（.json）か確認してください。',
    );
  }
  if (decoded is! Map<String, dynamic> || decoded['app'] != 'grow_app') {
    throw const BackupDecodeException(
      'このアプリのバックアップファイルではないようです。',
    );
  }

  final format = decoded['format'];
  if (format is! int || format > backupFormatVersion) {
    throw const BackupDecodeException(
      'より新しいバージョンのアプリで作成されたバックアップです。'
      'アプリを最新版に更新してから読み込んでください。',
    );
  }

  final rawChildren = decoded['children'];
  if (rawChildren is! List) {
    throw const BackupDecodeException('バックアップの内容が壊れています。');
  }

  final List<ChildProfile> children;
  try {
    children = rawChildren
        .map((e) => ChildProfile.fromJson(e as Map<String, dynamic>))
        .toList();
  } catch (_) {
    throw const BackupDecodeException(
      'データの復元に失敗しました。ファイルが壊れている可能性があります。',
    );
  }

  if (children.isEmpty) {
    throw const BackupDecodeException(
      'バックアップにお子様のデータが含まれていません。',
    );
  }
  return children;
}

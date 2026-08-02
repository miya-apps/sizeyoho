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

import '../models/birthday_memory.dart';
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
///
/// [includePhotos] を false にすると、写真（お子様のアイコン写真・
/// お誕生日の思い出写真）を除いて書き出す。クラウド保存では
/// 子どもの写真をサーバーに置かない方針のため false を使う。
/// 手動のファイルバックアップは利用者自身の管理下なので写真込み（true）。
String encodeBackupJson(
  List<ChildProfile> children, {
  bool includePhotos = true,
}) {
  return jsonEncode({
    'app': 'grow_app',
    'format': backupFormatVersion,
    'exportedAt': DateTime.now().toIso8601String(),
    'children': [
      for (final c in children)
        includePhotos ? c.toJson() : _stripPhotos(c.toJson()),
    ],
  });
}

/// toJson() が返した Map から写真データだけを取り除く。
Map<String, dynamic> _stripPhotos(Map<String, dynamic> json) {
  json['photoBytes'] = null;
  final memories = json['birthdayMemories'];
  if (memories is List) {
    for (final m in memories) {
      if (m is Map<String, dynamic>) m['photoBytes'] = null;
    }
  }
  return json;
}

/// 写真なしで復元されたデータに、いまの端末に残っている写真を引き継ぐ。
///
/// クラウドバックアップには写真が含まれないため、同じ端末で復元すると
/// 写真まで消えてしまう。復元データと同じお子様（ID一致）が端末にいる
/// 場合は、アイコン写真とお誕生日の思い出写真（年齢一致）を端末側から
/// 補って返す。復元データ側に写真がある場合はそちらを優先する。
List<ChildProfile> mergeLocalPhotos({
  required List<ChildProfile> restored,
  required List<ChildProfile> local,
}) {
  final localById = {for (final c in local) c.id: c};
  return [for (final r in restored) _mergeChildPhotos(r, localById[r.id])];
}

ChildProfile _mergeChildPhotos(ChildProfile restored, ChildProfile? local) {
  if (local == null) return restored;

  final memories = [
    for (final m in restored.birthdayMemories)
      m.photoBytes != null ? m : _mergeMemoryPhoto(m, local),
  ];
  return restored.copyWith(
    photoBytes: restored.photoBytes ?? local.photoBytes,
    birthdayMemories: memories,
  );
}

BirthdayMemory _mergeMemoryPhoto(BirthdayMemory memory, ChildProfile local) {
  for (final lm in local.birthdayMemories) {
    if (lm.age == memory.age && lm.photoBytes != null) {
      // 表示位置・拡大率は写真とセットの情報なので端末側の値を使う。
      return memory.copyWith(
        photoBytes: lm.photoBytes,
        photoAlignX: lm.photoAlignX,
        photoAlignY: lm.photoAlignY,
        photoScale: lm.photoScale,
      );
    }
  }
  return memory;
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

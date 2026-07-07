import 'dart:async';
import 'dart:math' as math;

import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/foundation.dart';
import 'package:shared_preferences/shared_preferences.dart';

import '../backup/growth_backup.dart';
import '../models/child_profile.dart';
import '../monetization/pro_status.dart';

/// Pro版「オンライン自動バックアップ」のクラウド接続部分。
///
/// 保存形式：既存のバックアップJSON（growth_backup.dart と同一形式）を
/// そのまま文字列チャンクに分割し、Firestore の
/// `users/{uid}/backup/chunk_N` に保存する。写真（base64）を含んでも
/// 1ドキュメント1MiBの制限に収まるようチャンクごとに分ける。
/// `users/{uid}` 本体にはメタ情報（チャンク数・日時・お子様名）を置く。
///
/// 復元は全チャンクを連結して decodeBackupJson に渡すだけなので、
/// 手動バックアップ（ファイル書き出し）と完全に互換。
class CloudBackup {
  CloudBackup._();

  static final CloudBackup instance = CloudBackup._();

  /// Firebase.initializeApp が成功していれば true（main.dart が設定する）。
  /// false のときは全機能が何もしない（オフライン・未設定でも安全）。
  static bool available = false;

  static const String _kAutoKey = 'cloud_auto_backup_v1';

  /// 1チャンクの最大文字数。日本語（UTF-8で3バイト）主体でも
  /// 1MiB制限に対して十分な余裕を持たせる。
  static const int _chunkChars = 250000;

  /// 自動バックアップのデバウンス（連続入力をまとめる）。
  static const Duration _debounceDuration = Duration(seconds: 5);

  /// サインイン中のユーザー（未サインインは null）。
  final ValueNotifier<User?> user = ValueNotifier<User?>(null);

  /// 自動バックアップのON/OFF（Pro＋サインイン時のみ意味を持つ）。
  final ValueNotifier<bool> autoBackupEnabled = ValueNotifier<bool>(true);

  /// 最後にクラウドへ保存できた日時（メタ情報から復元）。
  final ValueNotifier<DateTime?> lastBackupAt = ValueNotifier<DateTime?>(null);

  /// 通信中フラグ（UIのインジケータ用）。
  final ValueNotifier<bool> busy = ValueNotifier<bool>(false);

  Timer? _debounce;
  List<ChildProfile> _pending = const [];

  /// 起動時に一度呼ぶ（main.dart から）。
  Future<void> init() async {
    if (!available) return;
    final prefs = await SharedPreferences.getInstance();
    autoBackupEnabled.value = prefs.getBool(_kAutoKey) ?? true;
    FirebaseAuth.instance.authStateChanges().listen((u) {
      user.value = u;
      if (u != null) {
        _loadMeta(u);
      } else {
        lastBackupAt.value = null;
      }
    });
  }

  Future<void> setAutoBackupEnabled(bool enabled) async {
    autoBackupEnabled.value = enabled;
    final prefs = await SharedPreferences.getInstance();
    await prefs.setBool(_kAutoKey, enabled);
  }

  /// Googleアカウントでサインインする。成功なら null、失敗なら
  /// 利用者向けメッセージを返す。
  Future<String?> signInWithGoogle() async {
    if (!available) return 'クラウド機能を初期化できませんでした';
    try {
      final provider = GoogleAuthProvider();
      if (kIsWeb) {
        await FirebaseAuth.instance.signInWithPopup(provider);
      } else {
        await FirebaseAuth.instance.signInWithProvider(provider);
      }
      return null;
    } on FirebaseAuthException catch (e) {
      if (e.code == 'popup-closed-by-user' ||
          e.code == 'web-context-canceled' ||
          e.code == 'canceled') {
        return null; // 利用者キャンセルはエラー扱いしない
      }
      return 'サインインに失敗しました（${e.code}）';
    }
  }

  Future<void> signOut() async {
    if (!available) return;
    await FirebaseAuth.instance.signOut();
  }

  /// データ変更のたびに AppShell から呼ばれる。
  /// Pro・サインイン・自動ONのときだけ、少し待ってからまとめて保存する。
  void onDataChanged(List<ChildProfile> children) {
    if (!available) return;
    if (!ProStatus.isPro.value) return;
    if (user.value == null) return;
    if (!autoBackupEnabled.value) return;
    if (children.isEmpty) return;

    _pending = children;
    _debounce?.cancel();
    _debounce = Timer(_debounceDuration, () {
      backupNow(_pending);
    });
  }

  /// いますぐクラウドへ保存する。成功なら null、失敗ならメッセージを返す。
  Future<String?> backupNow(List<ChildProfile> children) async {
    if (!available) return 'クラウド機能を初期化できませんでした';
    final u = user.value;
    if (u == null) return 'サインインしていません';
    if (children.isEmpty) return '保存するデータがありません';

    _debounce?.cancel();
    busy.value = true;
    try {
      final json = encodeBackupJson(children);
      final chunks = <String>[
        for (var i = 0; i < json.length; i += _chunkChars)
          json.substring(i, math.min(i + _chunkChars, json.length)),
      ];

      final db = FirebaseFirestore.instance;
      final userDoc = db.collection('users').doc(u.uid);

      // 前回のチャンク数（減った分は後で消す）。
      final prev = await userDoc.get();
      final prevCount = (prev.data()?['chunkCount'] as num?)?.toInt() ?? 0;

      // 写真込みで合計が大きくなり得るため、1チャンクずつ書き込む
      // （バッチはリクエスト合計サイズの上限に当たりやすい）。
      for (var i = 0; i < chunks.length; i++) {
        await userDoc.collection('backup').doc('chunk_$i').set({
          'data': chunks[i],
        });
      }
      for (var i = chunks.length; i < prevCount; i++) {
        await userDoc.collection('backup').doc('chunk_$i').delete();
      }

      final now = DateTime.now();
      await userDoc.set({
        'chunkCount': chunks.length,
        'format': backupFormatVersion,
        'exportedAt': now.toIso8601String(),
        'childNames': [for (final c in children) c.displayName],
      });
      lastBackupAt.value = now;
      return null;
    } on FirebaseException catch (e) {
      return 'クラウドへの保存に失敗しました（${e.code}）';
    } finally {
      busy.value = false;
    }
  }

  /// クラウド上のバックアップの概要（無ければ null）。
  Future<CloudBackupInfo?> fetchInfo() async {
    if (!available || user.value == null) return null;
    final doc = await FirebaseFirestore.instance
        .collection('users')
        .doc(user.value!.uid)
        .get();
    final data = doc.data();
    if (data == null || (data['chunkCount'] as num? ?? 0) == 0) return null;
    return CloudBackupInfo(
      exportedAt: DateTime.tryParse(data['exportedAt'] as String? ?? ''),
      childNames: [
        for (final n in (data['childNames'] as List? ?? const [])) '$n',
      ],
    );
  }

  /// クラウドのバックアップを取得して復元用データにする。
  /// 失敗時は [BackupDecodeException] または [FirebaseException]。
  Future<List<ChildProfile>> fetchChildren() async {
    final u = user.value;
    if (!available || u == null) {
      throw const BackupDecodeException('サインインしていません。');
    }
    busy.value = true;
    try {
      final db = FirebaseFirestore.instance;
      final userDoc = db.collection('users').doc(u.uid);
      final meta = await userDoc.get();
      final count = (meta.data()?['chunkCount'] as num?)?.toInt() ?? 0;
      if (count == 0) {
        throw const BackupDecodeException(
          'クラウドにバックアップが見つかりませんでした。',
        );
      }
      final buffer = StringBuffer();
      for (var i = 0; i < count; i++) {
        final chunk = await userDoc.collection('backup').doc('chunk_$i').get();
        buffer.write(chunk.data()?['data'] as String? ?? '');
      }
      return decodeBackupJson(buffer.toString());
    } finally {
      busy.value = false;
    }
  }

  void _loadMeta(User u) async {
    try {
      final doc = await FirebaseFirestore.instance
          .collection('users')
          .doc(u.uid)
          .get();
      final exportedAt = doc.data()?['exportedAt'] as String?;
      lastBackupAt.value =
          exportedAt == null ? null : DateTime.tryParse(exportedAt);
    } on FirebaseException {
      // メタ情報が読めなくても致命的ではない（初回サインイン直後など）。
    }
  }
}

/// クラウド上のバックアップの概要（復元確認ダイアログ用）。
class CloudBackupInfo {
  const CloudBackupInfo({required this.exportedAt, required this.childNames});

  final DateTime? exportedAt;
  final List<String> childNames;
}

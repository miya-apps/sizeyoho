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
/// `users/{uid}/backup/{generation}--chunk_N` に保存する。
/// 全chunkの保存後に`users/{uid}`のactive generationを切り替えるため、
/// 通信失敗時に新旧chunkが混ざったbackupを公開しない。
///
/// プライバシー方針：写真（アイコン・お誕生日の思い出）はクラウドへ
/// 送信せず、端末内にのみ保存する（includePhotos: false でエンコード）。
/// 子どもの写真をサーバーで預からないことで、漏えいリスクと
/// ストア申告の負担を減らす。
///
/// 復元は全チャンクを連結して decodeBackupJson に渡すだけなので、
/// 手動バックアップ（ファイル書き出し）と互換。復元時の写真の
/// 引き継ぎは呼び出し側で mergeLocalPhotos を使って行う。
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
  bool _deletingAccount = false;
  Future<void> _backupQueue = Future<void>.value();
  int _activeBackupCount = 0;
  int _activeReadCount = 0;
  Completer<void>? _backupsIdle;

  /// 起動時に一度呼ぶ（main.dart から）。
  Future<void> init() async {
    if (!available) return;
    final prefs = await SharedPreferences.getInstance();
    autoBackupEnabled.value = prefs.getBool(_kAutoKey) ?? true;
    FirebaseAuth.instance.authStateChanges().listen((u) {
      // 旧accountで予約したデータを、新しいaccountへ送らない。
      if (user.value?.uid != u?.uid) _cancelPendingAutoBackup();
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
    if (!enabled) _cancelPendingAutoBackup();
    final prefs = await SharedPreferences.getInstance();
    await prefs.setBool(_kAutoKey, enabled);
  }

  /// Googleアカウントでサインインする。成功なら null、失敗なら
  /// 利用者向けメッセージを返す。
  Future<String?> signInWithGoogle() => _signInWithProvider(GoogleAuthProvider());

  /// Apple IDでサインインする（iOS/macOSアプリ版向け。Webは未設定時は失敗）。
  Future<String?> signInWithApple() {
    final provider = AppleAuthProvider();
    provider.addScope('email');
    return _signInWithProvider(provider);
  }

  Future<String?> _signInWithProvider(AuthProvider provider) async {
    if (!available) return 'クラウド機能を初期化できませんでした';
    try {
      UserCredential credential;
      if (kIsWeb) {
        credential = await FirebaseAuth.instance.signInWithPopup(provider);
      } else {
        credential = await FirebaseAuth.instance.signInWithProvider(provider);
      }
      // authStateChangesの配信を待たず、成功直後のUIにも反映する。
      user.value = credential.user;
      return null;
    } on FirebaseAuthException catch (e) {
      if (e.code == 'popup-closed-by-user' ||
          e.code == 'web-context-canceled' ||
          e.code == 'canceled') {
        return null;
      }
      // 障害調査用：unknown 等の詳細メッセージはログにだけ出す。
      debugPrint('signInWithProvider failed: code=${e.code} message=${e.message}');
      return 'サインインに失敗しました（${e.code}）';
    }
  }

  Future<void> signOut() async {
    if (!available) return;
    _cancelPendingAutoBackup();
    await FirebaseAuth.instance.signOut();
  }

  /// サインイン中のクラウドアカウントと、そのアカウントに紐づく
  /// Firestoreバックアップをアプリ内から削除する。
  ///
  /// 端末内の成長記録・写真は削除しない。Appleでサインインしている場合は
  /// 削除直前に再認証し、Appleのauthorization codeも失効させる。
  Future<String?> deleteAccount() async {
    if (!available) return 'クラウド機能を初期化できませんでした';
    if (_deletingAccount) return 'アカウントを削除しています';
    if (_activeReadCount > 0) return 'クラウドからの復元処理が終わってからお試しください';
    final currentUser = FirebaseAuth.instance.currentUser;
    if (currentUser == null) return 'サインインしていません';

    _deletingAccount = true;
    _debounce?.cancel();
    _pending = const [];
    busy.value = true;
    try {
      // すでに書き込み中のバックアップがある場合は完了を待つ。以後の
      // backupNow/onDataChangedは_deletingAccountで拒否し、削除後に
      // users/{uid}が再生成される競合を防ぐ。
      if (_activeBackupCount > 0) {
        await (_backupsIdle?.future ?? Future<void>.value());
      }

      final providerIds = currentUser.providerData
          .map((data) => data.providerId)
          .toSet();

      // この導線はiOSの「Appleでサインイン」専用。Google認証を使う
      // 公開済みAndroidへ未検証の再認証・削除フローを持ち込まない。
      if (!providerIds.contains('apple.com')) {
        return 'このアカウントはアプリ内削除の対象ではありません。お問い合わせからご連絡ください';
      }
      final provider = AppleAuthProvider()..addScope('email');
      final credential = kIsWeb
          ? await currentUser.reauthenticateWithPopup(provider)
          : await currentUser.reauthenticateWithProvider(provider);
      final authorizationCode =
          credential.additionalUserInfo?.authorizationCode;
      if (authorizationCode == null || authorizationCode.isEmpty) {
        return 'Apple IDの削除確認情報を取得できませんでした。時間をおいてお試しください';
      }
      final userDoc = FirebaseFirestore.instance
          .collection('users')
          .doc(currentUser.uid);
      final existing = await userDoc.get();
      final alreadyDeleting = existing.data()?['deleting'] == true;
      if (!alreadyDeleting) {
        // 個人内容を先に消し、削除中markerだけを残す。対応するrulesを本番へ
        // 反映すると、別端末の遅延writeが以後拒否される。
        await userDoc.set({
          'deleting': true,
          'deletedAt': FieldValue.serverTimestamp(),
        });
      }

      await FirebaseAuth.instance.revokeTokenWithAuthorizationCode(
        authorizationCode,
      );

      final chunks = await userDoc.collection('backup').get();
      for (final chunk in chunks.docs) {
        await chunk.reference.delete();
      }
      await currentUser.delete();
      lastBackupAt.value = null;
      return null;
    } on FirebaseAuthException catch (error) {
      if (error.code == 'web-context-canceled' ||
          error.code == 'canceled' ||
          error.code == 'popup-closed-by-user') {
        return 'アカウント削除をキャンセルしました';
      }
      if (error.code == 'requires-recent-login') {
        return '安全確認のため、いったんサインアウトして再度サインインしてからお試しください';
      }
      debugPrint(
        'deleteAccount auth failed: code=${error.code} message=${error.message}',
      );
      return 'アカウントを削除できませんでした（${error.code}）';
    } on FirebaseException catch (error) {
      debugPrint(
        'deleteAccount data deletion failed: '
        'code=${error.code} message=${error.message}',
      );
      return 'クラウドデータを削除できませんでした（${error.code}）';
    } finally {
      _deletingAccount = false;
      _syncBusy();
    }
  }

  /// データ変更のたびに AppShell から呼ばれる。
  /// Pro・サインイン・自動ONのときだけ、少し待ってからまとめて保存する。
  void onDataChanged(List<ChildProfile> children) {
    final currentUser = user.value;
    if (!available ||
        _deletingAccount ||
        !ProStatus.isPro.value ||
        currentUser == null ||
        !autoBackupEnabled.value ||
        children.isEmpty) {
      _cancelPendingAutoBackup();
      return;
    }

    final scheduledUid = currentUser.uid;
    _pending = List<ChildProfile>.unmodifiable(children);
    _debounce?.cancel();
    _debounce = Timer(_debounceDuration, () {
      _debounce = null;
      final snapshot = _pending;
      _pending = const [];
      if (_deletingAccount ||
          !ProStatus.isPro.value ||
          !autoBackupEnabled.value ||
          user.value?.uid != scheduledUid ||
          FirebaseAuth.instance.currentUser?.uid != scheduledUid) {
        return;
      }
      unawaited(
        _enqueueBackup(
          snapshot,
          scheduledUid,
          requiresAutoEnabled: true,
        ),
      );
    });
  }

  /// いますぐクラウドへ保存する。成功なら null、失敗ならメッセージを返す。
  Future<String?> backupNow(List<ChildProfile> children) async {
    if (!available) return 'クラウド機能を初期化できませんでした';
    if (_deletingAccount) return 'アカウントを削除しています';
    final u = user.value;
    if (u == null) return 'サインインしていません';
    if (children.isEmpty) return '保存するデータがありません';

    return _enqueueBackup(
      List<ChildProfile>.unmodifiable(children),
      u.uid,
      requiresAutoEnabled: false,
    );
  }

  Future<String?> _enqueueBackup(
    List<ChildProfile> children,
    String expectedUid, {
    required bool requiresAutoEnabled,
  }
  ) {
    if (_deletingAccount) {
      return Future<String?>.value('アカウントを削除しています');
    }
    late final String json;
    late final List<String> childNames;
    try {
      // queue待機中にmutableなChildProfileが変わっても内容が混ざらないよう、
      // 投入時点で写真を除いた完全なsnapshotへ変換する。
      json = encodeBackupJson(children, includePhotos: false);
      childNames = List<String>.unmodifiable(
        children.map((child) => child.displayName),
      );
    } catch (error) {
      debugPrint('Could not prepare cloud backup: $error');
      return Future<String?>.value('バックアップデータを準備できませんでした');
    }

    if (_activeBackupCount == 0) _backupsIdle = Completer<void>();
    _activeBackupCount++;
    _syncBusy();
    final result = Completer<String?>();
    _backupQueue = _backupQueue.then<void>((_) async {
      try {
        result.complete(
          await _performBackup(
            json,
            childNames,
            expectedUid,
            requiresAutoEnabled: requiresAutoEnabled,
          ),
        );
      } catch (error, stackTrace) {
        debugPrint('Unexpected cloud backup failure: $error\n$stackTrace');
        result.complete('クラウドへの保存に失敗しました');
      }
    }).whenComplete(() {
      _activeBackupCount--;
      if (_activeBackupCount == 0) {
        final idle = _backupsIdle;
        _backupsIdle = null;
        if (idle != null && !idle.isCompleted) idle.complete();
      }
      _syncBusy();
    });
    return result.future;
  }

  Future<String?> _performBackup(
    String json,
    List<String> childNames,
    String expectedUid, {
    required bool requiresAutoEnabled,
  }
  ) async {
    if (_deletingAccount) return 'アカウントを削除しています';
    if (!ProStatus.isPro.value) return 'オンラインバックアップはPro版の機能です';
    if (requiresAutoEnabled && !autoBackupEnabled.value) {
      return '自動バックアップがオフになったため、保存を中止しました';
    }
    if (user.value?.uid != expectedUid ||
        FirebaseAuth.instance.currentUser?.uid != expectedUid) {
      return 'サインイン先が変わったため、バックアップを中止しました';
    }
    try {
      final chunks = <String>[
        for (var i = 0; i < json.length; i += _chunkChars)
          json.substring(i, math.min(i + _chunkChars, json.length)),
      ];

      final db = FirebaseFirestore.instance;
      final userDoc = db.collection('users').doc(expectedUid);

      // 新generationへ全chunkを書いてから、root metadataを1回で切り替える。
      // 途中で失敗しても、復元側は以前のactive generationを読み続ける。
      final prev = await userDoc.get();
      final prevData = prev.data();
      final prevCount = (prev.data()?['chunkCount'] as num?)?.toInt() ?? 0;
      final previousGeneration =
          (prevData?['generation'] as String?) ??
          (prevCount > 0 ? 'legacy' : null);
      final generation = _newBackupGeneration();

      for (var i = 0; i < chunks.length; i++) {
        await userDoc
            .collection('backup')
            .doc('$generation--chunk_$i')
            .set({
          'data': chunks[i],
        });
      }

      if (_deletingAccount ||
          !ProStatus.isPro.value ||
          (requiresAutoEnabled && !autoBackupEnabled.value) ||
          user.value?.uid != expectedUid ||
          FirebaseAuth.instance.currentUser?.uid != expectedUid) {
        return 'サインイン状態が変わったため、バックアップを中止しました';
      }

      final now = DateTime.now();
      await userDoc.set({
        'chunkCount': chunks.length,
        'generation': generation,
        if (previousGeneration != null)
          'previousGeneration': previousGeneration,
        'checksum': _backupChecksum(json),
        'format': backupFormatVersion,
        'deleting': false,
        'exportedAt': now.toIso8601String(),
        'childNames': childNames,
      });
      lastBackupAt.value = now;

      // 古いgenerationをclientから即削除すると、別端末が同時保存中の
      // generationを消し得る。ここでは削除せず、account削除時に全件消す。
      // 保持期間cleanupを追加する場合はserver側TTL/transactionを別設計する。
      return null;
    } on FirebaseException catch (e) {
      return 'クラウドへの保存に失敗しました（${e.code}）';
    }
  }

  /// クラウド上のバックアップの概要（無ければ null）。
  Future<CloudBackupInfo?> fetchInfo() async {
    final requestedUser = user.value;
    if (!available || requestedUser == null) return null;
    final doc = await FirebaseFirestore.instance
        .collection('users')
        .doc(requestedUser.uid)
        .get();
    if (user.value?.uid != requestedUser.uid ||
        FirebaseAuth.instance.currentUser?.uid != requestedUser.uid) {
      return null;
    }
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
    _activeReadCount++;
    _syncBusy();
    try {
      final db = FirebaseFirestore.instance;
      final userDoc = db.collection('users').doc(u.uid);
      final meta = await userDoc.get();
      final metaData = meta.data();
      final count = (metaData?['chunkCount'] as num?)?.toInt() ?? 0;
      if (count == 0) {
        throw const BackupDecodeException(
          'クラウドにバックアップが見つかりませんでした。',
        );
      }
      final generation = metaData?['generation'] as String?;
      final buffer = StringBuffer();
      for (var i = 0; i < count; i++) {
        final chunkId = generation == null
            ? 'chunk_$i'
            : '$generation--chunk_$i';
        final chunk = await userDoc.collection('backup').doc(chunkId).get();
        final data = chunk.data()?['data'] as String?;
        if (data == null) {
          throw const BackupDecodeException(
            'クラウドのバックアップが不完全です。もう一度保存してください。',
          );
        }
        buffer.write(data);
      }
      final json = buffer.toString();
      final expectedChecksum = metaData?['checksum'] as String?;
      if (expectedChecksum != null &&
          expectedChecksum != _backupChecksum(json)) {
        throw const BackupDecodeException(
          'クラウドのバックアップを検証できませんでした。もう一度保存してください。',
        );
      }
      if (user.value?.uid != u.uid ||
          FirebaseAuth.instance.currentUser?.uid != u.uid) {
        throw const BackupDecodeException(
          'サインイン先が変わったため、復元を中止しました。',
        );
      }
      return decodeBackupJson(json);
    } finally {
      _activeReadCount--;
      _syncBusy();
    }
  }

  void _cancelPendingAutoBackup() {
    _debounce?.cancel();
    _debounce = null;
    _pending = const [];
  }

  void _syncBusy() {
    busy.value =
        _deletingAccount || _activeBackupCount > 0 || _activeReadCount > 0;
  }

  static String _backupChecksum(String value) {
    var hash = 0x811c9dc5;
    for (final unit in value.codeUnits) {
      hash ^= unit;
      hash = (hash * 0x01000193) & 0xffffffff;
    }
    return hash.toRadixString(16).padLeft(8, '0');
  }

  static String _newBackupGeneration() {
    final random = math.Random.secure();
    final hex = StringBuffer('g_');
    for (var i = 0; i < 16; i++) {
      hex.write(random.nextInt(256).toRadixString(16).padLeft(2, '0'));
    }
    return hex.toString();
  }

  void _loadMeta(User u) async {
    try {
      final doc = await FirebaseFirestore.instance
          .collection('users')
          .doc(u.uid)
          .get();
      final exportedAt = doc.data()?['exportedAt'] as String?;
      if (user.value?.uid != u.uid ||
          FirebaseAuth.instance.currentUser?.uid != u.uid) {
        return;
      }
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

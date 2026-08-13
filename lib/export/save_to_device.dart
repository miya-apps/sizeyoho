import 'dart:io' show Platform;

import 'package:file_saver/file_saver.dart';
import 'package:flutter/foundation.dart' show Uint8List, kIsWeb;

/// PDF・バックアップなど「1ファイルを端末に保存」する共通処理。
///
/// Android の [FileSaver.saveFile] はアプリ専用フォルダ
/// （Android/data/<パッケージ名>/files）に書き込むため、ファイルマネージャー
/// からほぼ見えず「保存したのにどこにも無い」状態になる。Android では
/// 保存先を選ぶシステムダイアログ（saveAs）を開き、ユーザーが選んだ場所
/// （ダウンロード等）に保存する。
///
/// 戻り値は実際に保存されたかどうか。ダイアログでキャンセルした場合は
/// false（エラーではないので呼び出し側は失敗表示にしないこと）。
Future<bool> saveBytesToDevice({
  required String name,
  required Uint8List bytes,
  required String fileExtension,
  required MimeType mimeType,
}) async {
  if (!kIsWeb && Platform.isAndroid) {
    final uri = await FileSaver.instance.saveAs(
      name: name,
      bytes: bytes,
      fileExtension: fileExtension,
      mimeType: mimeType,
    );
    return uri != null;
  }
  // Web はブラウザのダウンロード、iOS はアプリの書類フォルダに保存される。
  await FileSaver.instance.saveFile(
    name: name,
    bytes: bytes,
    fileExtension: fileExtension,
    mimeType: mimeType,
  );
  return true;
}

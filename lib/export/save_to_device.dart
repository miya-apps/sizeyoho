import 'dart:io' show Platform;

import 'package:file_saver/file_saver.dart';
import 'package:flutter/foundation.dart' show Uint8List, kIsWeb;

/// PDF・バックアップなど「1ファイルを端末に保存」する共通処理。
///
/// Android / iOS の [FileSaver.saveFile] はアプリ専用フォルダ
/// （Android/data/<パッケージ名>/files）に書き込むため、ファイルマネージャー
/// や「ファイル」アプリから見つけにくい。Android / iOS では保存先を選ぶ
/// システムダイアログ（saveAs）を開き、利用者が選んだ場所に保存する。
///
/// 戻り値は実際に保存されたかどうか。ダイアログでキャンセルした場合は
/// false（エラーではないので呼び出し側は失敗表示にしないこと）。
Future<bool> saveBytesToDevice({
  required String name,
  required Uint8List bytes,
  required String fileExtension,
  required MimeType mimeType,
}) async {
  if (!kIsWeb && (Platform.isAndroid || Platform.isIOS)) {
    final uri = await FileSaver.instance.saveAs(
      name: name,
      bytes: bytes,
      fileExtension: fileExtension,
      mimeType: mimeType,
    );
    return uri != null;
  }
  // Web はブラウザのダウンロード、それ以外のデスクトップ環境は
  // FileSaver が選ぶ標準の保存先へ書き込む。
  await FileSaver.instance.saveFile(
    name: name,
    bytes: bytes,
    fileExtension: fileExtension,
    mimeType: mimeType,
  );
  return true;
}

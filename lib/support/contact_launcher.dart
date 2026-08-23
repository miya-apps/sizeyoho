import 'package:flutter/material.dart';

import '../app/app_info.dart';
import 'contact_launcher_platform.dart';

/// 公式サイトのページを、既存のプラットフォーム別URL起動処理で開く。
///
/// Android・iOSでは外部ブラウザ、Webでは新しいタブを使用する。
/// 起動できなかった場合は、呼び出し元の画面にメッセージを表示する。
Future<void> openExternalPage(
  BuildContext context, {
  required String url,
  required String pageName,
}) async {
  final launched = await openContactFormUrl(url);
  if (!context.mounted) return;
  if (!launched) {
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text('$pageNameを開けませんでした。しばらくしてからお試しください。'),
      ),
    );
  }
}

/// お問い合わせページ（公式サイト contact.html）を外部ブラウザで開く。
/// フォームへ直接飛ばさず、問い合わせの種類や注意事項を確認できるページを挟む。
Future<void> openContactForm(BuildContext context) {
  return openExternalPage(
    context,
    url: kContactPageUrl,
    pageName: 'お問い合わせページ',
  );
}

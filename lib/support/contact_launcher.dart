import 'package:flutter/material.dart';

import '../app/app_info.dart';
import 'contact_launcher_platform.dart';

/// お問い合わせページ（公式サイト contact.html）を外部ブラウザで開く。
/// フォームへ直接飛ばさず、問い合わせの種類や注意事項を確認できるページを挟む。
Future<void> openContactForm(BuildContext context) async {
  final launched = await openContactFormUrl(kContactPageUrl);
  if (!context.mounted) return;
  if (!launched) {
    ScaffoldMessenger.of(context).showSnackBar(
      const SnackBar(
        content: Text('お問い合わせページを開けませんでした。しばらくしてからお試しください。'),
      ),
    );
  }
}

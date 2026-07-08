import 'package:flutter/material.dart';

import '../app/app_info.dart';
import 'contact_launcher_platform.dart';

/// お問い合わせフォーム（Googleフォーム）を外部ブラウザで開く。
Future<void> openContactForm(BuildContext context) async {
  final launched = await openContactFormUrl(kContactFormUrl);
  if (!context.mounted) return;
  if (!launched) {
    ScaffoldMessenger.of(context).showSnackBar(
      const SnackBar(
        content: Text('お問い合わせフォームを開けませんでした。しばらくしてからお試しください。'),
      ),
    );
  }
}

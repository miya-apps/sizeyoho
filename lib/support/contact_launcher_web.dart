import 'package:web/web.dart' as web;

/// Flutter Web：新しいタブでフォームを開く。
Future<bool> openContactFormUrl(String url) async {
  web.window.open(url, '_blank');
  return true;
}

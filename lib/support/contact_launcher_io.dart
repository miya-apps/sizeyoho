import 'package:url_launcher/url_launcher.dart';

/// Android / iOS など：外部ブラウザでフォームを開く。
Future<bool> openContactFormUrl(String url) {
  return launchUrl(
    Uri.parse(url),
    mode: LaunchMode.externalApplication,
  );
}

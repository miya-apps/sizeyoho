/// アプリの正式名称・バージョン。
/// 表示に使う名称はここで一元管理する（About・PDF・タイトルなど）。
library;

const String kAppName = 'サイズ予報';
const String kAppVersion = '1.0.0';

/// 公開Webサイト（独自ドメイン。GitHub Pages が miyaapps.com で配信）
const String kWebBaseUrl = 'https://miyaapps.com/sizeyoho';

/// 画像などに焼き込む表示用URL（スキームを省いた短い形）。
const String kWebDisplayUrl = 'miyaapps.com/sizeyoho';
const String kContactPageUrl = '$kWebBaseUrl/contact.html';
const String kPrivacyPolicyUrl = '$kWebBaseUrl/privacy.html';
const String kContactFormUrl =
    'https://docs.google.com/forms/d/e/1FAIpQLSfmVQ7BpgNVbbQRa-yVXuwOElXEzipLZ9OD_MH7jW-y5zW2qQ/viewform';

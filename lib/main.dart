import 'dart:async';

import 'package:firebase_core/firebase_core.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_localizations/flutter_localizations.dart';

import 'ads/ad_banner.dart';
import 'app/app_info.dart';
import 'app/app_shell.dart';
import 'cloud/cloud_backup.dart';
import 'firebase_options.dart';
import 'monetization/purchase_manager.dart';
import 'theme/app_theme.dart';

Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();
  // 縦向き固定（スマホ・タブレット共通）。横向きはレイアウト最適化の
  // 割にメリットが薄く、崩れのリスクだけが残るため対応しない。
  await SystemChrome.setPreferredOrientations([
    DeviceOrientation.portraitUp,
  ]);
  // 起動画面の見た目は web/index.html のスプラッシュに任せる。
  // ここでは Firebase 初期化だけ行い、二重表示を避ける。
  try {
    await Firebase.initializeApp(
      options: DefaultFirebaseOptions.currentPlatform,
    );
    CloudBackup.available = true;
    await CloudBackup.instance.init();
  } catch (_) {
    CloudBackup.available = false;
  }
  // 広告と課金（Android/iOSのみ）。起動を待たせないよう並行初期化。
  unawaited(initializeAds());
  unawaited(PurchaseManager.instance.init());
  runApp(const GrowApp());
}

class GrowApp extends StatelessWidget {
  const GrowApp({super.key});

  @override
  Widget build(BuildContext context) {
    return ValueListenableBuilder<ThemeData>(
      valueListenable: appThemeNotifier,
      builder: (context, appTheme, _) => MaterialApp(
        title: kAppName,
        debugShowCheckedModeBanner: false,
        theme: appTheme,
        locale: const Locale('ja', 'JP'),
        localizationsDelegates: const [
          GlobalMaterialLocalizations.delegate,
          GlobalWidgetsLocalizations.delegate,
          GlobalCupertinoLocalizations.delegate,
        ],
        supportedLocales: const [
          Locale('ja', 'JP'),
        ],
        home: const AppShell(),
      ),
    );
  }
}

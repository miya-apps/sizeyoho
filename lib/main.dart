import 'package:firebase_core/firebase_core.dart';
import 'package:flutter/material.dart';
import 'package:flutter_localizations/flutter_localizations.dart';

import 'app/app_info.dart';
import 'app/app_shell.dart';
import 'cloud/cloud_backup.dart';
import 'firebase_options.dart';
import 'theme/app_theme.dart';

Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();
  // クラウド（Pro版バックアップ）の初期化。失敗しても
  // アプリ本体はオフラインで問題なく動くため、起動は続行する。
  try {
    await Firebase.initializeApp(
      options: DefaultFirebaseOptions.currentPlatform,
    );
    CloudBackup.available = true;
    await CloudBackup.instance.init();
  } catch (_) {
    CloudBackup.available = false;
  }
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

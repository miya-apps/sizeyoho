import 'dart:async';

import 'package:firebase_core/firebase_core.dart';
import 'package:flutter/foundation.dart'
    show TargetPlatform, defaultTargetPlatform, kIsWeb;
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_localizations/flutter_localizations.dart';

import 'ads/ad_banner.dart';
import 'app/app_info.dart';
import 'app/app_shell.dart';
import 'cloud/cloud_backup.dart';
import 'firebase_options.dart';
import 'monetization/purchase_manager.dart';
import 'monetization/pro_status.dart';
import 'theme/app_theme.dart';

Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();
  // 縦向き固定（スマホ・タブレット共通）。横向きはレイアウト最適化の
  // 割にメリットが薄く、崩れのリスクだけが残るため対応しない。
  await SystemChrome.setPreferredOrientations([
    DeviceOrientation.portraitUp,
  ]);
  // 保存済みの購読状態を広告より先に確定する。これを待たないと、Pro利用者
  // でも起動直後に広告リクエストが発生する可能性がある。
  try {
    await ProStatus.load();
  } catch (error) {
    // 保存領域の一時的な障害だけでアプリ全体を起動不能にしない。
    // 読み込めない場合は安全側（無料版）で続行する。
    debugPrint('Saved Pro status could not be loaded: $error');
  }
  final isIosApp =
      !kIsWeb && defaultTargetPlatform == TargetPlatform.iOS;
  if (isIosApp) {
    // StoreKitの現在権利は端末上で確認できるため、初回画面を出す前に
    // 保存済みcacheを更新する。失敗時は後続init/復帰時に再試行する。
    await PurchaseManager.instance.refreshIosEntitlements();
  }
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
  // 公開済みAndroidは既存どおり広告・課金を並行初期化する。iOSだけは
  // StoreKitの権利確認を先に行い、無料利用者と確認できた場合に限って
  // UMP / Mobile Adsを開始する。
  if (isIosApp) {
    unawaited(_initializeIosCommerceAndAds());
  } else {
    unawaited(initializeAds());
    unawaited(PurchaseManager.instance.init());
  }
  runApp(const GrowApp());
}

Future<void> _initializeIosCommerceAndAds() async {
  try {
    await PurchaseManager.instance.init();
  } catch (error) {
    // 予期しないストア初期化失敗でもアプリを終了させず、
    // 次回resumeやペイウォールの商品再読込から回復できる状態にする。
    debugPrint('iOS commerce initialization failed: $error');
  } finally {
    startIosAdLifecycle();
  }
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

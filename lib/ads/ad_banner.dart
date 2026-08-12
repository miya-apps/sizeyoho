import 'dart:async';
import 'dart:io' show Platform;

import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:google_mobile_ads/google_mobile_ads.dart';

import '../monetization/pro_status.dart';

/// 画面下部のバナー広告（無料版のみ・Android/iOSのみ）。
///
/// - Pro版では何も表示しない（高さ0）
/// - Flutter Web では AdMob が使えないため何も表示しない
/// - 読み込みが終わるまでも高さ0（レイアウトが跳ねないよう最小限）
class AdBanner extends StatefulWidget {
  const AdBanner({super.key});

  /// バナーの広告ユニットID（アプリIDとは別物）。
  /// 開発中は誤タップによるポリシー違反を避けるため必ずGoogle公式テストIDを使い、
  /// リリースビルドのみ本番IDで配信する。
  static const String _androidUnitId = kDebugMode
      ? 'ca-app-pub-3940256099942544/6300978111' // Google公式テストID
      : 'ca-app-pub-7890458320134528/1069454919'; // 本番（サイズ予報 下部バナー）
  static const String _iosUnitId = kDebugMode
      ? 'ca-app-pub-3940256099942544/2934735716' // Google公式テストID
      : 'ca-app-pub-7890458320134528/6216592970'; // 本番（サイズ予報 下部バナー）

  static bool get _supported =>
      !kIsWeb && (Platform.isAndroid || Platform.isIOS);

  @override
  State<AdBanner> createState() => _AdBannerState();
}

class _AdBannerState extends State<AdBanner> {
  BannerAd? _ad;
  bool _loaded = false;

  /// 読み込み失敗時の再試行。本番の広告ユニットは在庫状況（no fill）で
  /// 普通に失敗するため、起動時の1回だけだとそのセッション中ずっと
  /// 広告が出ないままになる。間隔を広げながら数回だけ再試行する。
  Timer? _retryTimer;
  int _retryCount = 0;
  static const int _maxRetries = 5;

  @override
  void initState() {
    super.initState();
    if (AdBanner._supported && !ProStatus.isPro.value) {
      _load();
    }
    // Pro状態が切り替わったら広告を破棄／読み込みし直す。
    ProStatus.isPro.addListener(_onProChanged);
  }

  void _onProChanged() {
    if (!mounted) return;
    if (ProStatus.isPro.value) {
      _retryTimer?.cancel();
      _ad?.dispose();
      setState(() {
        _ad = null;
        _loaded = false;
      });
    } else if (AdBanner._supported && _ad == null) {
      _retryCount = 0;
      _load();
    }
  }

  /// 失敗回数に応じて間隔を広げつつ再読み込みを予約する（30秒→60秒→…）。
  void _scheduleRetry() {
    if (_retryCount >= _maxRetries) return;
    final delay = Duration(seconds: 30 * (1 << _retryCount.clamp(0, 3)));
    _retryCount++;
    _retryTimer?.cancel();
    _retryTimer = Timer(delay, () {
      if (mounted && !ProStatus.isPro.value && _ad == null) _load();
    });
  }

  void _load() {
    final unitId = defaultTargetPlatform == TargetPlatform.iOS
        ? AdBanner._iosUnitId
        : AdBanner._androidUnitId;
    final ad = BannerAd(
      adUnitId: unitId,
      size: AdSize.banner,
      request: const AdRequest(),
      listener: BannerAdListener(
        onAdLoaded: (_) {
          if (mounted) {
            _retryCount = 0;
            setState(() => _loaded = true);
          }
        },
        onAdFailedToLoad: (ad, error) {
          debugPrint('AdBanner failed to load: $error');
          ad.dispose();
          if (mounted) {
            setState(() {
              _ad = null;
              _loaded = false;
            });
            _scheduleRetry();
          }
        },
      ),
    );
    _ad = ad;
    ad.load();
  }

  @override
  void dispose() {
    ProStatus.isPro.removeListener(_onProChanged);
    _retryTimer?.cancel();
    _ad?.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final ad = _ad;
    if (!AdBanner._supported || !_loaded || ad == null) {
      return const SizedBox.shrink();
    }
    return SafeArea(
      top: false,
      child: SizedBox(
        width: ad.size.width.toDouble(),
        height: ad.size.height.toDouble(),
        child: AdWidget(ad: ad),
      ),
    );
  }
}

/// アプリ起動時に一度だけ呼ぶ（main.dart から）。
Future<void> initializeAds() async {
  if (!AdBanner._supported) return;
  await MobileAds.instance.initialize();
}

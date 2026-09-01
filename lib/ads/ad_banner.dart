import 'dart:async';
import 'dart:io' show Platform;

import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:google_mobile_ads/google_mobile_ads.dart';

import '../monetization/purchase_manager.dart';
import '../monetization/pro_status.dart';

/// UMPが広告リクエストを許可し、Mobile Adsの初期化も完了した状態。
final ValueNotifier<bool> adRequestsReady = ValueNotifier<bool>(false);

/// UMPの「広告のプライバシー設定」を設定画面に出す必要があるか。
final ValueNotifier<bool> adPrivacyOptionsRequired = ValueNotifier<bool>(false);

bool _mobileAdsInitialized = false;
bool _androidAdsInitializationStarted = false;
bool _iosAdLifecycleStarted = false;
bool _iosConsentFlowStarted = false;
Timer? _iosConsentRetryTimer;
int _iosConsentRetryCount = 0;
const List<Duration> _iosConsentRetryDelays = [
  Duration(seconds: 30),
  Duration(minutes: 1),
  Duration(minutes: 2),
];
Timer? _androidAdsRetryTimer;
int _androidAdsRetryCount = 0;
const List<Duration> _androidAdsRetryDelays = [
  Duration(seconds: 30),
  Duration(minutes: 1),
  Duration(minutes: 2),
];

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
    _tryLoad();
    // Pro状態、同意状態、iOSのStoreKit権利確認が切り替わったら、広告を
    // 破棄／読み込みし直す。
    ProStatus.isPro.addListener(_onProChanged);
    adRequestsReady.addListener(_onAvailabilityChanged);
    PurchaseManager.instance.entitlementsReady.addListener(
      _onAvailabilityChanged,
    );
  }

  bool get _mayLoad =>
      AdBanner._supported &&
      adRequestsReady.value &&
      (!Platform.isIOS || PurchaseManager.instance.entitlementsReady.value) &&
      !ProStatus.isPro.value;

  void _tryLoad() {
    if (_mayLoad && _ad == null) _load();
  }

  void _onAvailabilityChanged() {
    if (!mounted) return;
    if (!_mayLoad) {
      _disposeCurrentAd();
      return;
    }
    _retryCount = 0;
    _tryLoad();
  }

  void _onProChanged() {
    if (!mounted) return;
    if (ProStatus.isPro.value) {
      _disposeCurrentAd();
    } else {
      _onAvailabilityChanged();
    }
  }

  void _disposeCurrentAd() {
    _retryTimer?.cancel();
    _ad?.dispose();
    if (_ad == null && !_loaded) return;
    setState(() {
      _ad = null;
      _loaded = false;
    });
  }

  /// 失敗回数に応じて間隔を広げつつ再読み込みを予約する（30秒→60秒→…）。
  void _scheduleRetry() {
    if (_retryCount >= _maxRetries) return;
    final delay = Duration(seconds: 30 * (1 << _retryCount.clamp(0, 3)));
    _retryCount++;
    _retryTimer?.cancel();
    _retryTimer = Timer(delay, () {
      if (mounted && _mayLoad && _ad == null) _load();
    });
  }

  void _load() {
    if (!_mayLoad || _ad != null) return;
    final unitId = defaultTargetPlatform == TargetPlatform.iOS
        ? AdBanner._iosUnitId
        : AdBanner._androidUnitId;
    final ad = BannerAd(
      adUnitId: unitId,
      size: AdSize.banner,
      request: const AdRequest(),
      listener: BannerAdListener(
        onAdLoaded: (loadedAd) {
          if (!mounted || !_mayLoad || !identical(_ad, loadedAd)) {
            loadedAd.dispose();
            return;
          }
          _retryCount = 0;
          setState(() => _loaded = true);
        },
        onAdFailedToLoad: (ad, error) {
          debugPrint('AdBanner failed to load: $error');
          ad.dispose();
          if (mounted && identical(_ad, ad)) {
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
    adRequestsReady.removeListener(_onAvailabilityChanged);
    PurchaseManager.instance.entitlementsReady.removeListener(
      _onAvailabilityChanged,
    );
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
      bottom: false,
      child: Center(
        child: SizedBox(
          width: ad.size.width.toDouble(),
          height: ad.size.height.toDouble(),
          child: AdWidget(ad: ad),
        ),
      ),
    );
  }
}

/// アプリ起動時に一度だけ呼ぶ（main.dart から）。
Future<void> initializeAds() async {
  if (!AdBanner._supported) return;
  if (Platform.isAndroid && _androidAdsInitializationStarted) return;

  try {
    // AndroidはSDK初期化成功後に広告を許可し、失敗時は有限回再試行する。
    // iOSはGoogleの推奨順序でUMP同意を確認してから有効にする。
    if (Platform.isAndroid) {
      _androidAdsInitializationStarted = true;
      await _initializeMobileAds();
      adRequestsReady.value = true;
      _androidAdsRetryTimer?.cancel();
      _androidAdsRetryCount = 0;
      return;
    }

    // iOSはStoreKitの現在権利を確認できた無料利用者だけ広告フローへ進む。
    // Pro利用者の起動時にはUMP/GMA自体へアクセスしない。
    if (!PurchaseManager.instance.entitlementsReady.value ||
        ProStatus.isPro.value ||
        _iosConsentFlowStarted) {
      return;
    }
    _iosConsentFlowStarted = true;

    await MobileAds.instance.updateRequestConfiguration(
      RequestConfiguration(maxAdContentRating: MaxAdContentRating.g),
    );
    await _gatherIosConsent();
    await _refreshPrivacyOptionsRequirement();
    await _applyIosAdPermission();
    _iosConsentRetryTimer?.cancel();
    _iosConsentRetryCount = 0;
  } catch (error) {
    if (Platform.isIOS) {
      _iosConsentFlowStarted = false;
      // Google推奨どおり、更新失敗時も前sessionの同意状態で広告を
      // リクエスト可能か確認する。最新同意の取得自体は別途再試行する。
      try {
        await _applyIosAdPermission();
      } catch (fallbackError) {
        adRequestsReady.value = false;
        debugPrint('Previous UMP consent could not be applied: $fallbackError');
      }
      // 補助UIのstatus取得失敗で、上のcanRequestAds評価をskipしない。
      try {
        await _refreshPrivacyOptionsRequirement();
      } catch (privacyOptionsError) {
        debugPrint(
          'UMP privacy options status could not be refreshed: '
          '$privacyOptionsError',
        );
      }
      _scheduleIosConsentRetry();
    } else {
      _androidAdsInitializationStarted = false;
      adRequestsReady.value = false;
      _scheduleAndroidAdsRetry();
    }
    debugPrint('Mobile Ads initialization failed: $error');
  }
}

void _scheduleAndroidAdsRetry() {
  if (_androidAdsRetryCount >= _androidAdsRetryDelays.length) return;
  final delay = _androidAdsRetryDelays[_androidAdsRetryCount];
  _androidAdsRetryCount++;
  _androidAdsRetryTimer?.cancel();
  _androidAdsRetryTimer = Timer(delay, () => unawaited(initializeAds()));
}

/// StoreKitの権利確認後にiOS広告のライフサイクルを開始する。
/// 起動時にProなら何も送信せず、後日失効が確認された時だけ初期化する。
void startIosAdLifecycle() {
  if (!AdBanner._supported || !Platform.isIOS || _iosAdLifecycleStarted) {
    return;
  }
  _iosAdLifecycleStarted = true;
  ProStatus.isPro.addListener(_syncIosAdLifecycle);
  PurchaseManager.instance.entitlementsReady.addListener(_syncIosAdLifecycle);
  _syncIosAdLifecycle();
}

void _syncIosAdLifecycle() {
  if (PurchaseManager.instance.entitlementsReady.value &&
      !ProStatus.isPro.value) {
    unawaited(initializeAds());
  }
}

void _scheduleIosConsentRetry() {
  if (_iosConsentRetryCount >= _iosConsentRetryDelays.length ||
      ProStatus.isPro.value ||
      !PurchaseManager.instance.entitlementsReady.value) {
    return;
  }
  final delay = _iosConsentRetryDelays[_iosConsentRetryCount];
  _iosConsentRetryCount++;
  _iosConsentRetryTimer?.cancel();
  _iosConsentRetryTimer = Timer(delay, _syncIosAdLifecycle);
}

Future<void> _initializeMobileAds() async {
  if (_mobileAdsInitialized) return;
  await MobileAds.instance.initialize();
  _mobileAdsInitialized = true;
}

Future<void> _gatherIosConsent() async {
  final update = Completer<void>();
  ConsentInformation.instance.requestConsentInfoUpdate(
    ConsentRequestParameters(),
    () {
      if (!update.isCompleted) update.complete();
    },
    (error) {
      debugPrint(
        'UMP consent update failed: code=${error.errorCode} '
        'message=${error.message}',
      );
      if (!update.isCompleted) {
        update.completeError(StateError('UMP consent update failed'));
      }
    },
  );
  // timeoutはnetwork updateだけに適用し、利用者が同意画面を読む時間を
  // 制限しない。これにより表示中formへretryが重なるのを防ぐ。
  await update.future.timeout(const Duration(seconds: 30));
  await _loadAndShowRequiredConsentForm();
}

Future<void> _loadAndShowRequiredConsentForm() async {
  FormError? formError;
  await ConsentForm.loadAndShowConsentFormIfRequired((error) {
    formError = error;
  });
  final error = formError;
  if (error != null) {
    debugPrint(
      'UMP consent form failed: code=${error.errorCode} '
      'message=${error.message}',
    );
    throw StateError('UMP consent form failed');
  }
}

Future<void> _refreshPrivacyOptionsRequirement() async {
  final status = await ConsentInformation.instance
      .getPrivacyOptionsRequirementStatus();
  adPrivacyOptionsRequired.value =
      status == PrivacyOptionsRequirementStatus.required;
}

Future<void> _applyIosAdPermission() async {
  // UMP待機中に購入が完了した場合、Pro利用者ではGMAを初期化しない。
  if (ProStatus.isPro.value ||
      !PurchaseManager.instance.entitlementsReady.value) {
    adRequestsReady.value = false;
    _iosConsentFlowStarted = false;
    return;
  }
  final canRequestAds = await ConsentInformation.instance.canRequestAds();
  if (ProStatus.isPro.value ||
      !PurchaseManager.instance.entitlementsReady.value) {
    adRequestsReady.value = false;
    _iosConsentFlowStarted = false;
    return;
  }
  if (canRequestAds && !ProStatus.isPro.value) {
    await _initializeMobileAds();
  }
  adRequestsReady.value =
      canRequestAds && _mobileAdsInitialized && !ProStatus.isPro.value;
}

/// UMPが要求する場合に、利用者が同意内容を後から変更するための画面を開く。
/// 成功時はnull、表示できない場合は利用者向けメッセージを返す。
Future<String?> showAdPrivacyOptions() async {
  if (!AdBanner._supported || !Platform.isIOS) {
    return 'この環境では広告のプライバシー設定を表示できません';
  }
  try {
    FormError? formError;
    await ConsentForm.showPrivacyOptionsForm((error) {
      formError = error;
    });
    final error = formError;
    await _refreshPrivacyOptionsRequirement();
    await _applyIosAdPermission();
    if (error == null) return null;
    debugPrint(
      'UMP privacy options failed: code=${error.errorCode} '
      'message=${error.message}',
    );
    return '広告のプライバシー設定を開けませんでした';
  } catch (error) {
    debugPrint('UMP privacy options failed: $error');
    return '広告のプライバシー設定を開けませんでした';
  }
}

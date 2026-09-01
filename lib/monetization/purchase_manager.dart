import 'dart:async';
import 'dart:io' show Platform;

import 'package:flutter/foundation.dart';
import 'package:flutter/services.dart';
import 'package:flutter/widgets.dart';
import 'package:in_app_purchase/in_app_purchase.dart';
import 'package:in_app_purchase_android/in_app_purchase_android.dart';

import 'pro_status.dart';

/// プランID（paywallから[PurchaseManager.buy]に渡す論理ID）。
///
/// ストア側の構成はプラットフォームで異なる：
/// - Google Play：1つの定期購入 [_kPlaySubscriptionId] の中に、
///   このIDと同名の「基本プラン」が2つある（Play推奨の構成）。
/// - App Store：月額・年額の商品を2つ登録する。商品IDは保存後に変更
///   できないため、App Store Connectでもこの値をそのまま使う。
final String kProMonthlyProductId = !kIsWeb && Platform.isIOS
    ? 'sizeyoho_pro_monthly'
    : 'sizeyoho-pro-monthly';
final String kProYearlyProductId = !kIsWeb && Platform.isIOS
    ? 'sizeyoho_pro_yearly'
    : 'sizeyoho-pro-yearly';

/// Google Playの定期購入アイテムID（この中に月額・年額の基本プランを持つ）。
const String _kPlaySubscriptionId = 'sizeyoho_pro';

/// ストアから取得した、利用者の地域・通貨に合った表示価格。
class ProProductCatalog {
  const ProProductCatalog({this.monthlyPrice, this.yearlyPrice});

  final String? monthlyPrice;
  final String? yearlyPrice;

  bool get monthlyAvailable => monthlyPrice != null;
  bool get yearlyAvailable => yearlyPrice != null;
}

/// Pro版サブスクリプションの購入・復元・現在の権利確認。
class PurchaseManager with WidgetsBindingObserver {
  PurchaseManager._();

  static final PurchaseManager instance = PurchaseManager._();

  /// 購入完了・復元時にPro有効化の対象とみなすproductID。
  /// Androidの購入結果は基本プランではなく親の定期購入IDで届く。
  static final Set<String> _productIds = {
    kProMonthlyProductId,
    kProYearlyProductId,
    _kPlaySubscriptionId,
  };

  static const MethodChannel _storeKitChannel = MethodChannel(
    'com.miyaapps.sizeyoho/storekit',
  );

  /// ストア課金が使える環境か（Android/iOSかつストア接続OK）。
  final ValueNotifier<bool> storeAvailable = ValueNotifier<bool>(false);

  /// 購入処理中フラグ（ボタンの二度押し防止・インジケータ用）。
  final ValueNotifier<bool> busy = ValueNotifier<bool>(false);

  /// iOSのStoreKit 2で現在の権利を確認し終えたか。広告はこの値がtrueに
  /// なるまで待ち、期限切れ直後の利用者へ誤って広告リクエストしない。
  final ValueNotifier<bool> entitlementsReady = ValueNotifier<bool>(false);

  /// ストアの商品情報を少なくとも1回取得し終えたか。
  final ValueNotifier<bool> catalogLoadComplete = ValueNotifier<bool>(false);

  /// App Store / Google Playから取得したローカライズ済み価格。
  final ValueNotifier<ProProductCatalog> catalog =
      ValueNotifier<ProProductCatalog>(const ProProductCatalog());

  /// purchaseStreamで後から届くエラーやキャンセルを画面へ通知する。
  final ValueNotifier<String?> purchaseMessage = ValueNotifier<String?>(null);

  final Map<String, ProductDetails> _products = <String, ProductDetails>{};
  StreamSubscription<List<PurchaseDetails>>? _subscription;
  Future<void> _purchaseUpdateQueue = Future<void>.value();
  Future<bool>? _refreshingIosEntitlements;
  Set<String> _lastIosActiveProductIds = const <String>{};
  Timer? _iosEntitlementRefreshTimer;
  Future<void>? _initializing;
  bool _initialized = false;
  bool _observingLifecycle = false;
  bool _purchaseInFlight = false;
  bool _restoreInFlight = false;
  bool _catalogRefreshInFlight = false;
  bool _processingPurchaseUpdates = false;

  static bool get _supported =>
      !kIsWeb && (Platform.isAndroid || Platform.isIOS);

  /// Google Playは購入開始時にも親商品を再照会できるため、初回の商品情報
  /// 取得に失敗しても購入ボタンから再試行できる。App Storeでは価格を表示
  /// できない商品を購入させない。
  bool get canAttemptPurchaseWithoutCatalog =>
      !kIsWeb && Platform.isAndroid;

  /// 起動時に一度だけ呼ぶ（main.dartから）。
  Future<void> init() {
    if (_initialized) return Future<void>.value();
    final initializing = _initializing;
    if (initializing != null) return initializing;

    final future = _initOnce();
    _initializing = future;
    return future.whenComplete(() {
      if (identical(_initializing, future)) _initializing = null;
    });
  }

  Future<void> _initOnce() async {
    if (!_supported) {
      entitlementsReady.value = true;
      catalogLoadComplete.value = true;
      _initialized = true;
      return;
    }

    final iap = InAppPurchase.instance;

    // 公式推奨どおり、ストアの可用性確認より先に取引ストリームを購読する。
    _subscription ??= iap.purchaseStream.listen(
      (purchases) {
        // async callbackを直接listenへ渡すと複数eventが並行実行され得るため、
        // 権利更新とtransaction完了を到着順に直列化する。
        _purchaseUpdateQueue = _purchaseUpdateQueue
            .then((_) => _onPurchaseUpdates(purchases))
            .catchError((Object error, StackTrace stackTrace) {
              debugPrint('Purchase update processing failed: $error');
              _purchaseInFlight = false;
              _processingPurchaseUpdates = false;
              _syncBusy();
              _setMessage('購入情報を処理できませんでした。時間をおいてお試しください');
            });
      },
      onError: (Object _) {
        _purchaseInFlight = false;
        _processingPurchaseUpdates = false;
        _syncBusy();
        _setMessage('購入情報を確認できませんでした。時間をおいてお試しください');
      },
    );

    if (Platform.isIOS) {
      if (!_observingLifecycle) {
        WidgetsBinding.instance.addObserver(this);
        _observingLifecycle = true;
      }
      _startIosEntitlementRefreshTimer();
      await refreshIosEntitlements();
    } else {
      // 公開済みAndroidは既存の保存済みPro判定を維持する。
      entitlementsReady.value = true;
    }

    await refreshCatalog();
    _initialized = true;
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    if (kIsWeb || !Platform.isIOS) return;
    if (state == AppLifecycleState.resumed) {
      _startIosEntitlementRefreshTimer();
      unawaited(refreshIosEntitlements());
    } else {
      _iosEntitlementRefreshTimer?.cancel();
    }
  }

  void _startIosEntitlementRefreshTimer() {
    if (kIsWeb || !Platform.isIOS) return;
    _iosEntitlementRefreshTimer?.cancel();
    // StoreKitの失効・返金・Grace Period終了がforeground継続中に起きても、
    // 次のresumeを待たず1分以内に権利を更新する。
    _iosEntitlementRefreshTimer = Timer.periodic(
      const Duration(minutes: 1),
      (_) => unawaited(refreshIosEntitlements()),
    );
  }

  Future<void> _loadCatalog() async {
    try {
      final ids = Platform.isIOS
          ? <String>{kProMonthlyProductId, kProYearlyProductId}
          : <String>{_kPlaySubscriptionId};
      final response = await InAppPurchase.instance.queryProductDetails(ids);
      final monthly = _selectProduct(
        response.productDetails,
        kProMonthlyProductId,
      );
      final yearly = _selectProduct(
        response.productDetails,
        kProYearlyProductId,
      );
      _products
        ..clear()
        ..addEntries([
          if (monthly != null) MapEntry(kProMonthlyProductId, monthly),
          if (yearly != null) MapEntry(kProYearlyProductId, yearly),
        ]);
      catalog.value = ProProductCatalog(
        monthlyPrice: monthly?.price,
        yearlyPrice: yearly?.price,
      );
    } catch (_) {
      _products.clear();
      catalog.value = const ProProductCatalog();
    }
  }

  /// ストア接続と商品情報を再確認する。ペイウォールの「再読み込み」からも
  /// 呼べるため、一時的な通信失敗でそのセッション中ずっと購入不能にならない。
  Future<void> refreshCatalog({bool userInitiated = false}) async {
    if (!_supported) {
      catalogLoadComplete.value = true;
      return;
    }
    if (userInitiated && busy.value) return;
    if (userInitiated) {
      _catalogRefreshInFlight = true;
      _syncBusy();
    }
    catalogLoadComplete.value = false;
    try {
      try {
        storeAvailable.value = await InAppPurchase.instance.isAvailable();
      } catch (_) {
        storeAvailable.value = false;
      }
      if (storeAvailable.value) {
        await _loadCatalog();
      } else {
        _products.clear();
        catalog.value = const ProProductCatalog();
      }
    } finally {
      catalogLoadComplete.value = true;
      if (userInitiated) {
        _catalogRefreshInFlight = false;
        _syncBusy();
      }
    }
  }

  /// 商品を購入する。成功・失敗の結果はpurchaseStream側で処理される。
  /// 開始できなかった場合のみ利用者向けメッセージを返す。
  Future<String?> buy(String planId) async {
    if (!_supported || !storeAvailable.value) {
      return 'この環境では購入できません。アプリ版（App Store・Google Play）をご利用ください';
    }
    if (busy.value) return '別の購入・復元処理を実行中です';
    _purchaseInFlight = true;
    _syncBusy();
    purchaseMessage.value = null;
    try {
      // iOSはプランごとに商品が分かれる。Androidは親の定期購入を
      // 照会すると基本プランごとにProductDetailsが返る。
      final storeProductId = Platform.isIOS ? planId : _kPlaySubscriptionId;
      var product = _products[planId];
      if (product == null) {
        final response = await InAppPurchase.instance.queryProductDetails({
          storeProductId,
        });
        product = _selectProduct(response.productDetails, planId);
      }
      if (product == null) {
        _purchaseInFlight = false;
        _syncBusy();
        return '商品情報を取得できませんでした。時間をおいてお試しください';
      }
      final started = await InAppPurchase.instance.buyNonConsumable(
        purchaseParam: PurchaseParam(productDetails: product),
      );
      if (!started) {
        _purchaseInFlight = false;
        _syncBusy();
        return '購入を開始できませんでした';
      }
      return null;
    } catch (_) {
      _purchaseInFlight = false;
      _syncBusy();
      return '購入処理でエラーが発生しました。時間をおいてお試しください';
    }
  }

  /// 照会結果から、購入したいプランに対応するProductDetailsを選ぶ。
  static ProductDetails? _selectProduct(
    List<ProductDetails> products,
    String planId,
  ) {
    if (products.isEmpty) return null;
    if (Platform.isIOS) {
      for (final product in products) {
        if (product.id == planId) return product;
      }
      return null;
    }

    // Android：基本プランごとに1件ずつ返るGooglePlayProductDetailsから、
    // basePlanIdがプランIDと一致するものを選ぶ。
    for (final product in products) {
      if (product is! GooglePlayProductDetails) continue;
      final offers = product.productDetails.subscriptionOfferDetails;
      final index = product.subscriptionIndex;
      if (offers == null || index == null || index >= offers.length) continue;
      if (offers[index].basePlanId == planId) return product;
    }
    return null;
  }

  /// 過去の購入を復元する（機種変更後など）。
  Future<String?> restore() async {
    if (!_supported || !storeAvailable.value) {
      return 'この環境では復元できません。アプリ版をご利用ください';
    }
    if (busy.value) return '別の購入・復元処理を実行中です';
    _restoreInFlight = true;
    _syncBusy();
    purchaseMessage.value = null;
    try {
      await InAppPurchase.instance.restorePurchases();
      if (Platform.isIOS) {
        final checked = await refreshIosEntitlements(
          forceFreshAfterCurrent: true,
        );
        if (!checked) {
          return '購入状態を確認できませんでした。時間をおいてお試しください';
        }
        if (!ProStatus.isPro.value) {
          return '復元できる有効なPro版の購入が見つかりませんでした';
        }
      }
      return null;
    } catch (_) {
      return '復元処理でエラーが発生しました';
    } finally {
      _restoreInFlight = false;
      _syncBusy();
    }
  }

  Future<void> _onPurchaseUpdates(List<PurchaseDetails> purchases) async {
    _processingPurchaseUpdates = true;
    _syncBusy();
    var hasPendingPurchase = false;
    try {
      for (final purchase in purchases) {
        var mayComplete = true;
        switch (purchase.status) {
          case PurchaseStatus.purchased:
          case PurchaseStatus.restored:
            // 未知の商品は履行せず、将来/廃止商品の権利を誤って捨てない。
            mayComplete = false;
            if (_productIds.contains(purchase.productID)) {
              if (Platform.isIOS) {
                final checked = await refreshIosEntitlements(
                  forceFreshAfterCurrent: true,
                );
                mayComplete = purchase.status == PurchaseStatus.restored
                    ? checked
                    : checked &&
                          _lastIosActiveProductIds.contains(
                            purchase.productID,
                          );
                if (!checked) {
                  _setMessage(
                    '購入の検証に失敗しました。時間をおいて「購入を復元」をお試しください',
                  );
                } else if (!ProStatus.isPro.value) {
                  _setMessage('有効なPro版の購入を確認できませんでした');
                }
              } else {
                // 公開済みAndroidの既存挙動は維持する。
                try {
                  await ProStatus.setActive(true);
                  mayComplete = true;
                } catch (error) {
                  mayComplete = false;
                  debugPrint('Could not persist Android Pro status: $error');
                  _setMessage(
                    '購入情報を端末に保存できませんでした。アプリを再起動してください',
                  );
                }
              }
            } else {
              debugPrint(
                'Purchase received for an unknown product: '
                '${purchase.productID}',
              );
              _setMessage('この購入商品を確認できませんでした。サポートへお問い合わせください');
            }
          case PurchaseStatus.error:
            _setMessage(purchase.error?.message ?? '購入処理でエラーが発生しました');
          case PurchaseStatus.canceled:
            _setMessage('購入はキャンセルされました');
          case PurchaseStatus.pending:
            // 保留中。完了時に再度ストリームへ流れる。
            _setMessage('購入処理が保留中です。ストアで状態をご確認ください');
            mayComplete = false;
            hasPendingPurchase = true;
        }

        if (mayComplete && purchase.pendingCompletePurchase) {
          try {
            await InAppPurchase.instance.completePurchase(purchase);
          } catch (_) {
            _setMessage('購入の完了処理に失敗しました。アプリを再起動してください');
          }
        }
      }
    } finally {
      // restore中のstream eventだけではrestoreフラグを解除しない。
      // pendingがある場合だけ、後続eventが届くまで購入中を維持する。
      _purchaseInFlight = hasPendingPurchase;
      _processingPurchaseUpdates = false;
      _syncBusy();
    }
  }

  /// StoreKit 2の検証済み`currentEntitlements`をネイティブ側で読み、
  /// 期限切れ・返金・取消を含めた「現在有効な権利」でPro状態を更新する。
  /// 呼び出し自体に失敗した場合は保存値を消さずfalseを返す。
  Future<bool> refreshIosEntitlements({
    bool forceFreshAfterCurrent = false,
  }) async {
    if (kIsWeb || !Platform.isIOS) return true;
    final refreshing = _refreshingIosEntitlements;
    if (refreshing != null) {
      final result = await refreshing;
      if (!forceFreshAfterCurrent) return result;
      // transaction/restore後は、購入前に始まったquery結果を流用せず、
      // 進行中queryの完了後に必ずもう一度StoreKitを読む。
      return refreshIosEntitlements();
    }
    final query = _refreshIosEntitlementsOnce();
    late final Future<bool> tracked;
    tracked = query.whenComplete(() {
      if (identical(_refreshingIosEntitlements, tracked)) {
        _refreshingIosEntitlements = null;
      }
    });
    _refreshingIosEntitlements = tracked;
    return tracked;
  }

  Future<bool> _refreshIosEntitlementsOnce() async {
    try {
      final activeIds =
          await _storeKitChannel.invokeListMethod<String>(
            'currentEntitlements',
          ) ??
          const <String>[];
      final active = activeIds.any(
        (id) => id == kProMonthlyProductId || id == kProYearlyProductId,
      );
      // StoreKit照会自体は成功したため、local cache保存とは分離して
      // transactionを完了できる状態にする。notifierはsetActive内で先に更新される。
      _lastIosActiveProductIds = activeIds.toSet();
      final persistence = ProStatus.setActive(active);
      entitlementsReady.value = true;
      try {
        await persistence;
      } catch (error) {
        debugPrint(
          'Could not persist the StoreKit entitlement result: $error',
        );
      }
      return true;
    } on PlatformException catch (error) {
      debugPrint(
        'StoreKit entitlement check failed: '
        'code=${error.code} message=${error.message}',
      );
      return false;
    } on MissingPluginException catch (error) {
      debugPrint('StoreKit entitlement channel is unavailable: $error');
      return false;
    } catch (error) {
      debugPrint('StoreKit entitlement check failed: $error');
      return false;
    }
  }

  void _setMessage(String message) {
    // 同じ文言が続いてもValueNotifierが通知するよう、一度nullへ戻す。
    purchaseMessage.value = null;
    purchaseMessage.value = message;
  }

  void _syncBusy() {
    busy.value =
        _purchaseInFlight ||
        _restoreInFlight ||
        _catalogRefreshInFlight ||
        _processingPurchaseUpdates;
  }

  void dispose() {
    _subscription?.cancel();
    _iosEntitlementRefreshTimer?.cancel();
    if (_observingLifecycle) WidgetsBinding.instance.removeObserver(this);
  }
}

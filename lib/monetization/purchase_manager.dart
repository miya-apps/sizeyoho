import 'dart:async';
import 'dart:io' show Platform;

import 'package:flutter/foundation.dart';
import 'package:in_app_purchase/in_app_purchase.dart';

import 'pro_status.dart';

/// ストア商品ID。
/// Google Play のサブスクリプションIDは「数字・小文字・ハイフン」のみで
/// アンダースコアが使えず、逆に App Store は「英数字・アンダースコア・
/// ピリオド」のみでハイフンが使えないため、プラットフォーム別のIDにする。
final String kProMonthlyProductId = !kIsWeb && Platform.isIOS
    ? 'sizeyoho_pro_monthly'
    : 'sizeyoho-pro-monthly';
final String kProYearlyProductId = !kIsWeb && Platform.isIOS
    ? 'sizeyoho_pro_yearly'
    : 'sizeyoho-pro-yearly';

/// Pro版サブスクリプションの購入・復元。
///
/// in_app_purchase 経由でストア課金を行い、購入/復元が確認できたら
/// [ProStatus] を有効にする。Web ではストア課金が存在しないため
/// すべて何もしない（[storeAvailable] が false のまま）。
class PurchaseManager {
  PurchaseManager._();

  static final PurchaseManager instance = PurchaseManager._();

  static final Set<String> _productIds = {
    kProMonthlyProductId,
    kProYearlyProductId,
  };

  /// ストア課金が使える環境か（Android/iOS かつストア接続OK）。
  final ValueNotifier<bool> storeAvailable = ValueNotifier<bool>(false);

  /// 購入処理中フラグ（ボタンの二度押し防止・インジケータ用）。
  final ValueNotifier<bool> busy = ValueNotifier<bool>(false);

  StreamSubscription<List<PurchaseDetails>>? _subscription;

  static bool get _supported =>
      !kIsWeb && (Platform.isAndroid || Platform.isIOS);

  /// 起動時に一度だけ呼ぶ（main.dart から）。
  Future<void> init() async {
    if (!_supported) return;
    final iap = InAppPurchase.instance;
    try {
      storeAvailable.value = await iap.isAvailable();
    } catch (_) {
      storeAvailable.value = false;
    }
    if (!storeAvailable.value) return;

    // 購入・復元・保留などの結果はすべてこのストリームに届く。
    _subscription = iap.purchaseStream.listen(
      _onPurchaseUpdates,
      onError: (Object _) => busy.value = false,
    );
  }

  /// 商品を購入する。成功・失敗の結果は purchaseStream 側で処理される。
  /// 開始できなかった場合のみ利用者向けメッセージを返す。
  Future<String?> buy(String productId) async {
    if (!_supported || !storeAvailable.value) {
      return 'この環境では購入できません。アプリ版（App Store・Google Play）をご利用ください';
    }
    busy.value = true;
    try {
      final response =
          await InAppPurchase.instance.queryProductDetails({productId});
      final product = response.productDetails.isEmpty
          ? null
          : response.productDetails.first;
      if (product == null) {
        busy.value = false;
        return '商品情報を取得できませんでした。時間をおいてお試しください';
      }
      final started = await InAppPurchase.instance.buyNonConsumable(
        purchaseParam: PurchaseParam(productDetails: product),
      );
      if (!started) {
        busy.value = false;
        return '購入を開始できませんでした';
      }
      return null;
    } catch (_) {
      busy.value = false;
      return '購入処理でエラーが発生しました。時間をおいてお試しください';
    }
  }

  /// 過去の購入を復元する（機種変更後など）。
  Future<String?> restore() async {
    if (!_supported || !storeAvailable.value) {
      return 'この環境では復元できません。アプリ版をご利用ください';
    }
    busy.value = true;
    try {
      await InAppPurchase.instance.restorePurchases();
      return null;
    } catch (_) {
      return '復元処理でエラーが発生しました';
    } finally {
      busy.value = false;
    }
  }

  void _onPurchaseUpdates(List<PurchaseDetails> purchases) {
    for (final purchase in purchases) {
      switch (purchase.status) {
        case PurchaseStatus.purchased:
        case PurchaseStatus.restored:
          if (_productIds.contains(purchase.productID)) {
            ProStatus.setActive(true);
          }
        case PurchaseStatus.error:
        case PurchaseStatus.canceled:
          break;
        case PurchaseStatus.pending:
          // コンビニ払いなどの保留。完了時に再度ストリームに流れる。
          continue;
      }
      if (purchase.pendingCompletePurchase) {
        InAppPurchase.instance.completePurchase(purchase);
      }
      busy.value = false;
    }
  }

  void dispose() {
    _subscription?.cancel();
  }
}

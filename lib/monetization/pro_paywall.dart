import 'dart:async';

import 'package:flutter/material.dart';

import '../app/app_info.dart';
import '../support/contact_launcher.dart';
import 'pro_status.dart';
import 'purchase_manager.dart';

/// Pro版の案内（ペイウォール）シートを開く。
///
/// 鍵付きのPro限定表示をタップしたときに呼ぶ。
/// プラン選択で PurchaseManager 経由のストア購入を開始する。
Future<void> showProPaywallSheet(BuildContext context) {
  // 起動時のストア初期化が一時失敗していても、利用者が購入画面を開いた
  // タイミングで再試行できるようにする。
  unawaited(PurchaseManager.instance.init());
  return showModalBottomSheet<void>(
    context: context,
    showDragHandle: true,
    isScrollControlled: true,
    builder: (_) => const _ProPaywallSheet(),
  );
}

class _ProPaywallSheet extends StatefulWidget {
  const _ProPaywallSheet();

  @override
  State<_ProPaywallSheet> createState() => _ProPaywallSheetState();
}

class _ProPaywallSheetState extends State<_ProPaywallSheet> {
  static const Color _gold = Color(0xFFB8860B);

  @override
  void initState() {
    super.initState();
    // 購入・復元が完了（purchaseStream 経由で Pro 有効化）したら
    // シートを自動で閉じてお礼を表示する。
    ProStatus.isPro.addListener(_onProChanged);
    PurchaseManager.instance.purchaseMessage.addListener(_onPurchaseMessage);
  }

  @override
  void dispose() {
    ProStatus.isPro.removeListener(_onProChanged);
    PurchaseManager.instance.purchaseMessage.removeListener(_onPurchaseMessage);
    super.dispose();
  }

  void _onProChanged() {
    if (!ProStatus.isPro.value || !mounted) return;
    final messenger = ScaffoldMessenger.of(context);
    Navigator.of(context).pop();
    messenger.showSnackBar(
      const SnackBar(
        content: Text('Pro版が有効になりました。ありがとうございます！'),
        behavior: SnackBarBehavior.floating,
      ),
    );
  }

  void _onPurchaseMessage() {
    final message = PurchaseManager.instance.purchaseMessage.value;
    if (message == null || !mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(content: Text(message), behavior: SnackBarBehavior.floating),
    );
  }

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    return SafeArea(
      child: SingleChildScrollView(
        padding: const EdgeInsets.fromLTRB(24, 4, 24, 24),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            const Icon(
              Icons.workspace_premium_rounded,
              size: 44,
              color: _gold,
            ),
            const SizedBox(height: 8),
            const Text(
              'サイズ予報 Pro',
              textAlign: TextAlign.center,
              style: TextStyle(fontSize: 18, fontWeight: FontWeight.w800),
            ),
            const SizedBox(height: 6),
            Text(
              '「次はいつ・何cmを買えばいい？」まで、\nひと目でわかるようになります。',
              textAlign: TextAlign.center,
              style: TextStyle(
                fontSize: 12.5,
                height: 1.6,
                color: Colors.grey[700],
              ),
            ),
            const SizedBox(height: 16),
            _feature(
              icon: Icons.query_stats_rounded,
              scheme: scheme,
              title: 'サイズの先読みシミュレーション',
              body: '靴の「次の購入サイズと時期」＋その先の予報',
            ),
            _feature(
              icon: Icons.image_outlined,
              scheme: scheme,
              title: 'ガイド・グラフの画像保存',
              body: '成長曲線・SDスコア・おむつ・洋服・靴を'
                  '共有しやすい正方形画像で保存',
            ),
            _feature(
              icon: Icons.cloud_done_outlined,
              scheme: scheme,
              title: 'オンライン自動バックアップ',
              body: '機種変更や故障に備えて記録を自動でクラウドに保存（写真を除く）',
            ),
            _feature(
              icon: Icons.block_flipped,
              scheme: scheme,
              title: '広告非表示',
              body: '画面下の広告が表示されなくなります',
            ),
            const SizedBox(height: 18),
            AnimatedBuilder(
              animation: Listenable.merge([
                PurchaseManager.instance.catalog,
                PurchaseManager.instance.storeAvailable,
                PurchaseManager.instance.catalogLoadComplete,
                PurchaseManager.instance.busy,
              ]),
              builder: (context, _) {
                final manager = PurchaseManager.instance;
                final catalog = manager.catalog.value;
                final busy = manager.busy.value;
                final storeAvailable = manager.storeAvailable.value;
                final loadComplete = manager.catalogLoadComplete.value;
                final retryFromButton =
                    manager.canAttemptPurchaseWithoutCatalog;
                final monthlyEnabled =
                    storeAvailable &&
                    (catalog.monthlyAvailable || retryFromButton);
                final yearlyEnabled =
                    storeAvailable &&
                    (catalog.yearlyAvailable || retryFromButton);
                final missingProduct =
                    !catalog.monthlyAvailable || !catalog.yearlyAvailable;

                return Column(
                  children: [
                    Row(
                      children: [
                        Expanded(
                          child: _planButton(
                            context,
                            label: '月額プラン',
                            price:
                                catalog.monthlyPrice ??
                                (retryFromButton ? 'ストアで確認' : '—'),
                            sub: '1か月ごとの自動更新',
                            emphasized: false,
                            onPressed: busy || !monthlyEnabled
                                ? null
                                : () => _buy(
                                    context,
                                    kProMonthlyProductId,
                                  ),
                          ),
                        ),
                        const SizedBox(width: 10),
                        Expanded(
                          child: _planButton(
                            context,
                            label: '年額プラン',
                            price:
                                catalog.yearlyPrice ??
                                (retryFromButton ? 'ストアで確認' : '—'),
                            sub: '1年ごとの自動更新',
                            emphasized: true,
                            onPressed: busy || !yearlyEnabled
                                ? null
                                : () => _buy(
                                    context,
                                    kProYearlyProductId,
                                  ),
                          ),
                        ),
                      ],
                    ),
                    if (!loadComplete || !storeAvailable || missingProduct) ...[
                      const SizedBox(height: 8),
                      Text(
                        !loadComplete
                            ? 'ストアの商品情報を読み込んでいます…'
                            : !storeAvailable
                            ? 'ストアに接続できませんでした。通信状態をご確認ください。'
                            : retryFromButton
                            ? '価格は購入確認画面に表示されます。取得できない場合は再読み込みしてください。'
                            : '商品情報を取得できませんでした。ストアの商品設定をご確認ください。',
                        textAlign: TextAlign.center,
                        style: TextStyle(
                          fontSize: 10.5,
                          color: Colors.grey[700],
                        ),
                      ),
                      if (loadComplete)
                        TextButton(
                          onPressed: busy
                              ? null
                              : () => unawaited(
                                  manager.refreshCatalog(userInitiated: true),
                                ),
                          child: const Text('商品情報を再読み込み'),
                        ),
                    ],
                  ],
                );
              },
            ),
            const SizedBox(height: 10),
            ValueListenableBuilder<bool>(
              valueListenable: PurchaseManager.instance.busy,
              builder: (context, busy, _) => TextButton(
                onPressed: busy ? null : () => _restore(context),
                child: const Text(
                  '購入を復元する（機種変更後など）',
                  style: TextStyle(fontSize: 11.5),
                ),
              ),
            ),
            const SizedBox(height: 2),
            Text(
              '料金は税込です。定期購入は自動更新され、各ストアのアカウントに'
              '請求されます。\n'
              '解約は App Store・Google Play の定期購入設定から行えます。\n'
              '購入・復元は購入したストアごとに管理され、Google Playと'
              'App Storeの間でPro購入は引き継がれません。',
              textAlign: TextAlign.center,
              style: TextStyle(
                fontSize: 10.5,
                height: 1.6,
                color: Colors.grey[700],
              ),
            ),
            const SizedBox(height: 2),
            Wrap(
              alignment: WrapAlignment.center,
              crossAxisAlignment: WrapCrossAlignment.center,
              children: [
                _legalLink(
                  context,
                  label: '利用規約',
                  url: kTermsPageUrl,
                ),
                const Text(
                  '｜',
                  style: TextStyle(fontSize: 11, color: Color(0xFF777777)),
                ),
                _legalLink(
                  context,
                  label: 'プライバシーポリシー',
                  url: kPrivacyPolicyUrl,
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }

  Widget _feature({
    required IconData icon,
    required ColorScheme scheme,
    required String title,
    required String body,
  }) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 6),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Icon(icon, size: 20, color: scheme.primary),
          const SizedBox(width: 10),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  title,
                  style: const TextStyle(
                    fontSize: 13,
                    fontWeight: FontWeight.w700,
                  ),
                ),
                Text(
                  body,
                  style: TextStyle(
                    fontSize: 11,
                    height: 1.5,
                    color: Colors.grey[700],
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _legalLink(
    BuildContext context, {
    required String label,
    required String url,
  }) {
    return TextButton(
      onPressed: () => openExternalPage(
        context,
        url: url,
        pageName: label,
      ),
      style: TextButton.styleFrom(
        minimumSize: const Size(0, 48),
        padding: const EdgeInsets.symmetric(horizontal: 10),
        tapTargetSize: MaterialTapTargetSize.padded,
        textStyle: const TextStyle(
          fontSize: 11.5,
          fontWeight: FontWeight.w600,
        ),
      ),
      child: Text(label),
    );
  }

  /// 購入を開始する。エラーはシート上のスナックバーで知らせる。
  /// 成功時はpurchaseStream側でProStatusが有効になり、シートが閉じる。
  static Future<void> _buy(BuildContext context, String productId) async {
    final messenger = ScaffoldMessenger.of(context);
    final err = await PurchaseManager.instance.buy(productId);
    if (err != null) {
      messenger.showSnackBar(
        SnackBar(content: Text(err), behavior: SnackBarBehavior.floating),
      );
    }
  }

  static Future<void> _restore(BuildContext context) async {
    final messenger = ScaffoldMessenger.of(context);
    final err = await PurchaseManager.instance.restore();
    messenger.showSnackBar(
      SnackBar(
        content: Text(err ?? '復元処理を実行しました。購入履歴があればPro版が有効になります'),
        behavior: SnackBarBehavior.floating,
      ),
    );
  }

  Widget _planButton(
    BuildContext context, {
    required String label,
    required String price,
    required String sub,
    required bool emphasized,
    required VoidCallback? onPressed,
  }) {
    final scheme = Theme.of(context).colorScheme;
    final content = Column(
      mainAxisSize: MainAxisSize.min,
      children: [
        Text(label, style: const TextStyle(fontSize: 12)),
        const SizedBox(height: 2),
        Text(
          price,
          style: const TextStyle(fontSize: 18, fontWeight: FontWeight.w800),
        ),
        const SizedBox(height: 2),
        Text(sub, textAlign: TextAlign.center, style: const TextStyle(fontSize: 9.5)),
      ],
    );
    final shape = RoundedRectangleBorder(
      borderRadius: BorderRadius.circular(14),
    );
    const padding = EdgeInsets.symmetric(vertical: 12, horizontal: 8);

    return emphasized
        ? FilledButton(
            onPressed: onPressed,
            style: FilledButton.styleFrom(
              padding: padding,
              shape: shape,
              backgroundColor: scheme.primary,
              foregroundColor: Colors.black87,
            ),
            child: content,
          )
        : OutlinedButton(
            onPressed: onPressed,
            style: OutlinedButton.styleFrom(
              padding: padding,
              shape: shape,
              foregroundColor: Colors.grey[800],
            ),
            child: content,
          );
  }
}

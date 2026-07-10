import 'package:flutter/material.dart';

import 'pro_pricing.dart';
import 'pro_status.dart';
import 'purchase_manager.dart';

/// Pro版の案内（ペイウォール）シートを開く。
///
/// 鍵付きのPro限定表示をタップしたときに呼ぶ。
/// プラン選択で PurchaseManager 経由のストア購入を開始する。
Future<void> showProPaywallSheet(BuildContext context) {
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
  }

  @override
  void dispose() {
    ProStatus.isPro.removeListener(_onProChanged);
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
              icon: Icons.cloud_done_outlined,
              scheme: scheme,
              title: 'オンライン自動バックアップ',
              body: '機種変更や故障に備えて記録を自動でクラウドに保存',
            ),
            _feature(
              icon: Icons.block_flipped,
              scheme: scheme,
              title: '広告非表示',
              body: '画面下の広告が表示されなくなります',
            ),
            const SizedBox(height: 18),
            ValueListenableBuilder<bool>(
              valueListenable: PurchaseManager.instance.busy,
              builder: (context, busy, _) => Row(
                children: [
                  Expanded(
                    child: _planButton(
                      context,
                      label: '月額プラン',
                      price: proMonthlyPriceLabel,
                      sub: '毎月のお支払い',
                      emphasized: false,
                      onPressed: busy
                          ? null
                          : () => _buy(context, kProMonthlyProductId),
                    ),
                  ),
                  const SizedBox(width: 10),
                  Expanded(
                    child: _planButton(
                      context,
                      label: '年額プラン',
                      price: proYearlyPriceLabel,
                      sub: '$proYearlyPerMonthLabel・'
                          '約$proYearlyDiscountPercent%おトク',
                      emphasized: true,
                      onPressed: busy
                          ? null
                          : () => _buy(context, kProYearlyProductId),
                    ),
                  ),
                ],
              ),
            ),
            const SizedBox(height: 10),
            TextButton(
              onPressed: () => _restore(context),
              child: const Text(
                '購入を復元する（機種変更後など）',
                style: TextStyle(fontSize: 11.5),
              ),
            ),
            const SizedBox(height: 2),
            Text(
              '価格はすべて消費税込みです。\n'
              'お支払いは App Store / Google Play のアカウントに請求されます。',
              textAlign: TextAlign.center,
              style: TextStyle(
                fontSize: 10.5,
                height: 1.6,
                color: Colors.grey[600],
              ),
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
                    color: Colors.grey[600],
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  /// 購入を開始する。エラーはシートを閉じてスナックバーで知らせる
  /// （成功時は purchaseStream 側で ProStatus が有効になり、ぼかしが解ける）。
  static Future<void> _buy(BuildContext context, String productId) async {
    final messenger = ScaffoldMessenger.of(context);
    final navigator = Navigator.of(context);
    final err = await PurchaseManager.instance.buy(productId);
    if (err != null) {
      if (navigator.canPop()) navigator.pop();
      messenger.showSnackBar(
        SnackBar(content: Text(err), behavior: SnackBarBehavior.floating),
      );
    }
  }

  static Future<void> _restore(BuildContext context) async {
    final messenger = ScaffoldMessenger.of(context);
    final navigator = Navigator.of(context);
    final err = await PurchaseManager.instance.restore();
    if (navigator.canPop()) navigator.pop();
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

import 'package:flutter/material.dart';

import '../growth/diaper_master.dart';
import '../growth/diaper_master_data.g.dart' show kDiaperBrands;
import '../growth/diaper_size_guide.dart';
import 'diaper_badge.dart';
import 'diaper_status_pill.dart';

/// 1枠ぶんのおむつサイズ表示（バッジ＋名前＋タイプ／状態＋本文）。
///
/// [DiaperGuideView] の選択枠カードと、画像保存（Instagram向けスクショ）用の
/// おむつカードの両方から使う共通部品。見た目がずれないよう、判定結果
/// （[DiaperSlotGuide]）の描画ロジックを1か所にまとめている。
///
/// [onTap] を渡すとタップ可能な選択カードになり、右端に入替アイコンが出る。
/// 渡さない（null）場合は表示専用（画像保存など）になる。
class DiaperSlotSummaryCard extends StatelessWidget {
  const DiaperSlotSummaryCard({
    super.key,
    required this.series,
    required this.type,
    required this.isBoy,
    required this.guide,
    this.onTap,
  });

  final DiaperSeries series;
  final DiaperType type;
  final bool isBoy;

  /// 体重未記録などで判定できない場合は null（名前とタイプのみ表示）。
  final DiaperSlotGuide? guide;

  final VoidCallback? onTap;

  static const _titleColor = Color(0xFF1A1A1A);

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    final brand = findDiaperBrandById(kDiaperBrands, series.brandId);
    final name = brand == null
        ? series.displayName
        : diaperDisplayName(brand: brand, series: series, type: type);
    final pillKind = _statusPillKind(guide);

    final content = Container(
      padding: const EdgeInsets.fromLTRB(14, 12, 10, 12),
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: Colors.grey.withValues(alpha: 0.15)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              DiaperBadge(series: series, type: type, isBoy: isBoy, size: 32),
              const SizedBox(width: 10),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      name,
                      style: const TextStyle(
                        fontSize: 14.5,
                        fontWeight: FontWeight.w700,
                        color: _titleColor,
                      ),
                    ),
                    const SizedBox(height: 3),
                    Wrap(
                      spacing: 6,
                      runSpacing: 4,
                      crossAxisAlignment: WrapCrossAlignment.center,
                      children: [
                        _buildTypeBadge(scheme, type),
                        if (pillKind != null) DiaperStatusPill(kind: pillKind),
                      ],
                    ),
                  ],
                ),
              ),
              if (onTap != null)
                Icon(
                  Icons.swap_horiz_rounded,
                  size: 20,
                  color: Colors.grey[500],
                ),
            ],
          ),
          if (guide != null && guide!.fit.status != DiaperFitStatus.aboveRange) ...[
            const SizedBox(height: 10),
            _buildGuideBody(scheme, guide!),
          ],
        ],
      ),
    );

    if (onTap == null) {
      return Material(
        color: Colors.white,
        borderRadius: BorderRadius.circular(14),
        child: content,
      );
    }

    return Material(
      color: Colors.white,
      borderRadius: BorderRadius.circular(14),
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(14),
        child: content,
      ),
    );
  }

  /// テープ／パンツの種別バッジ（文字のみ）。
  Widget _buildTypeBadge(ColorScheme scheme, DiaperType type) =>
      DiaperTypeBadge(type: type);

  /// タイプバッジの右に並べる状態バッジの種類。
  DiaperStatusKind? _statusPillKind(DiaperSlotGuide? guide) =>
      diaperStatusPillKind(guide);

  /// 判定結果に応じた本文。
  /// - クリーン／真の重複：無印。サイズと範囲＋予報のみ
  /// - 内包・接している・隙間：縦積みのサイズ情報のみ
  /// - 最大到達：サイズと使える見込みのみ
  /// - 上限超過：呼び出し側で本文自体を表示しない
  Widget _buildGuideBody(ColorScheme scheme, DiaperSlotGuide guide) {
    switch (guide.fit.status) {
      case DiaperFitStatus.clean:
        return guide.fit.isMaxSize
            ? _buildMaxSizeBody(scheme, guide)
            : _buildCleanBody(scheme, guide);
      case DiaperFitStatus.inTransition:
        return _buildTransitionBody(scheme, guide);
      case DiaperFitStatus.belowRange:
        return _buildInfoText(
          '体重がこのシリーズの対象より軽いです。もう少し大きくなったら表示されます',
        );
      case DiaperFitStatus.aboveRange:
        return const SizedBox.shrink();
    }
  }

  /// クリーン（最大サイズ以外）：サイズはセンタリング、次のサイズ名は出さず
  /// 「あとどのくらい使えるか」だけを示す。
  Widget _buildCleanBody(ColorScheme scheme, DiaperSlotGuide guide) {
    final current = guide.currentBand!;
    final forecast = guide.nextSizeForecast;

    final children = <Widget>[
      _buildSizeLine(scheme, band: current, emphasized: true),
    ];

    if (forecast != null && forecast.weeksUntil > 0) {
      final weeks = roundedDiaperWeeks(forecast.weeksUntil);
      children
        ..add(const SizedBox(height: 4))
        ..add(_buildInfoText(
          '${_formatMonthLabel(forecast.approxDate)}まで使える見込み'
          '（残り約$weeks週間）',
          textAlign: TextAlign.center,
        ));
    }

    return SizedBox(
      width: double.infinity,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.center,
        children: children,
      ),
    );
  }

  /// ゆらぎの中。真の重複（重複区間の中）はクリーンと結論が同じ（今のサイズが
  /// 適切）なので無印で大きい方のサイズを出す。内包・接している・隙間は
  /// バッジ＋縦積みのサイズ情報。
  Widget _buildTransitionBody(ColorScheme scheme, DiaperSlotGuide guide) {
    final lower = guide.currentBand!;
    final upper = guide.nextBand!;

    if (guide.fit.assertiveTransition) {
      final end = guide.lowerSizeEndForecast;
      final String? lowerNote;
      if (end != null && end.weeksUntil > 0) {
        final weeks = roundedDiaperWeeks(end.weeksUntil);
        lowerNote = '${_formatMonthLabel(end.approxDate)}まで使える見込み'
            '（残り約$weeks週間）';
      } else {
        lowerNote = null;
      }

      return SizedBox(
        width: double.infinity,
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.center,
          children: [
            _buildTransitionSizeText(scheme, lower),
            if (lowerNote != null) ...[
              const SizedBox(height: 2),
              Text(
                lowerNote,
                textAlign: TextAlign.center,
                style: TextStyle(fontSize: 11, height: 1.4, color: Colors.grey[600]),
              ),
            ],
            const SizedBox(height: 3),
            const Text(
              '↓',
              style: TextStyle(
                fontSize: 15,
                fontWeight: FontWeight.w700,
                color: Color(0xFF8A8A8A),
                height: 1.1,
              ),
            ),
            const SizedBox(height: 3),
            _buildTransitionSizeText(scheme, upper),
          ],
        ),
      );
    }

    final end = guide.lowerSizeEndForecast;
    final lowerNote = (end != null && end.weeksUntil > 0)
        ? '※${_formatMonthLabel(end.approxDate)}まで'
        : null;

    return Column(
      mainAxisSize: MainAxisSize.min,
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        _buildTransitionSizeText(scheme, lower, note: lowerNote),
        const SizedBox(height: 1),
        const Center(
          child: Text(
            '↓',
            style: TextStyle(
              fontSize: 15,
              fontWeight: FontWeight.w700,
              color: Color(0xFF8A8A8A),
              height: 1.1,
            ),
          ),
        ),
        const SizedBox(height: 1),
        _buildTransitionSizeText(scheme, upper),
      ],
    );
  }

  /// サイズアップ中のサイズ表示。幅が狭くても中央寄せの1行を保つ。
  Widget _buildTransitionSizeText(
    ColorScheme scheme,
    DiaperSizeBand band, {
    String? note,
  }) =>
      Center(
        child: FittedBox(
          fit: BoxFit.scaleDown,
          child: Row(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.center,
            children: [
              _buildSizeChip(scheme, band.sizeLabel),
              const SizedBox(width: 6),
              Text.rich(
                TextSpan(
                  children: [
                    TextSpan(
                      text: '（${diaperRangeLabel(band)}）',
                      style: const TextStyle(
                        fontSize: 11.5,
                        fontWeight: FontWeight.w700,
                        color: _titleColor,
                        height: 1.2,
                      ),
                    ),
                    if (note != null)
                      TextSpan(
                        text: '　$note',
                        style: TextStyle(fontSize: 11, fontWeight: FontWeight.w600, color: Colors.grey[600]),
                      ),
                  ],
                ),
              ),
            ],
          ),
        ),
      );

  /// 最大サイズ到達（範囲内）：サイズと見込みはセンタリング。
  Widget _buildMaxSizeBody(ColorScheme scheme, DiaperSlotGuide guide) {
    final current = guide.currentBand!;
    final children = <Widget>[
      _buildSizeLine(scheme, band: current, emphasized: true),
    ];

    final end = guide.lowerSizeEndForecast;
    if (end != null && end.weeksUntil > 0) {
      final weeks = roundedDiaperWeeks(end.weeksUntil);
      children
        ..add(const SizedBox(height: 4))
        ..add(_buildInfoText(
          '${_formatMonthLabel(end.approxDate)}まで使える見込み'
          '（残り約$weeks週間）',
          textAlign: TextAlign.center,
        ));
    }

    return SizedBox(
      width: double.infinity,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.center,
        children: children,
      ),
    );
  }

  /// 「L（9〜14kg）」の1行（ラベル無し。サイズ名を強調・範囲を併記）。
  Widget _buildSizeLine(
    ColorScheme scheme, {
    required DiaperSizeBand band,
    bool emphasized = false,
  }) {
    return Row(
      mainAxisSize: MainAxisSize.min,
      crossAxisAlignment: CrossAxisAlignment.center,
      children: [
        _buildSizeChip(scheme, band.sizeLabel, emphasized: emphasized),
        const SizedBox(width: 6),
        Text(
          '（${diaperRangeLabel(band)}）',
          style: TextStyle(fontSize: 11.5, color: Colors.grey[700]),
        ),
      ],
    );
  }

  /// サイズ名だけを囲う共通のチップ。体重範囲・「※〇〇頃まで」は呼び出し側で
  /// 囲いの外に置く。
  Widget _buildSizeChip(
    ColorScheme scheme,
    String label, {
    bool emphasized = true,
  }) =>
      DiaperSizeChip(label: label, emphasized: emphasized);

  Widget _buildInfoText(String text, {TextAlign textAlign = TextAlign.start}) => Text(
        text,
        textAlign: textAlign,
        style: TextStyle(fontSize: 11.5, height: 1.5, color: Colors.grey[700]),
      );

  static String _formatMonthLabel(DateTime d) => formatDiaperForecastMonth(d);
}

/// タイプバッジの右に並べる状態バッジの種類。
/// 無印の状態（クリーン・真の重複・下回り）ではバッジを出さない。
/// 画面のカードと書き出し画像の両方で同じ判定を使う。
DiaperStatusKind? diaperStatusPillKind(DiaperSlotGuide? guide) {
  if (guide == null) return null;
  switch (guide.fit.status) {
    case DiaperFitStatus.clean:
      return guide.fit.isMaxSize ? DiaperStatusKind.max : null;
    case DiaperFitStatus.inTransition:
      return guide.fit.assertiveTransition ? null : DiaperStatusKind.sizeUp;
    case DiaperFitStatus.belowRange:
      return null;
    case DiaperFitStatus.aboveRange:
      return DiaperStatusKind.exceeds;
  }
}

/// 予測時期の表示（例：11月頃 / 来年3月頃 / 2028年5月頃）。靴ガイドと同じ粒度。
String formatDiaperForecastMonth(DateTime d) {
  final now = DateTime.now();
  if (d.year == now.year) return '${d.month}月頃';
  if (d.year == now.year + 1) return '来年${d.month}月頃';
  return '${d.year}年${d.month}月頃';
}

/// テープ／パンツの種別バッジ（文字のみ）。
class DiaperTypeBadge extends StatelessWidget {
  const DiaperTypeBadge({super.key, required this.type});

  final DiaperType type;

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    final color = Color.lerp(scheme.primary, Colors.black, 0.15)!;
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 7, vertical: 2.5),
      decoration: BoxDecoration(
        color: scheme.primary.withValues(alpha: 0.10),
        borderRadius: BorderRadius.circular(20),
      ),
      child: Text(
        diaperTypeLabel(type),
        style: TextStyle(fontSize: 10.5, fontWeight: FontWeight.w700, color: color),
      ),
    );
  }
}

/// サイズ名だけを囲う共通のチップ（§11：サイズ名の表記をすべて囲い付きに
/// 統一）。体重範囲・「※〇〇頃まで」は呼び出し側で囲いの外に置く。
class DiaperSizeChip extends StatelessWidget {
  const DiaperSizeChip({super.key, required this.label, this.emphasized = true});

  final String label;
  final bool emphasized;

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    // 文字色はテーマの onPrimaryContainer（seedColor を黒に寄せた濃色）を
    // 使い、薄い背景とのコントラストを確保する。
    final textColor = scheme.onPrimaryContainer;
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
      decoration: BoxDecoration(
        color: emphasized ? scheme.primary.withValues(alpha: 0.16) : Colors.transparent,
        borderRadius: BorderRadius.circular(6),
        border: Border.all(
          color: emphasized ? textColor.withValues(alpha: 0.55) : scheme.primary.withValues(alpha: 0.25),
          width: emphasized ? 1.2 : 1,
        ),
      ),
      child: Text(
        label,
        style: TextStyle(
          fontSize: 13.5,
          fontWeight: FontWeight.w700,
          color: emphasized ? textColor : Color.lerp(scheme.primary, Colors.black, 0.25),
          height: 1.2,
        ),
      ),
    );
  }
}

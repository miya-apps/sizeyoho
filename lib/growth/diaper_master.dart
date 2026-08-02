/// おむつガイドのマスタデータモデル。
///
/// データの正は `assets/diaper/` の CSV 3枚（brands / series / sizes）。
/// アプリは `tool/generate_diaper_data.dart` が生成する
/// `diaper_master_data.g.dart` の const データだけを読む
/// （実行時に CSV はパースしない）。
///
/// 体重帯（min/max kg）・シリーズの有無は各社の公表値であり、
/// コード側で推測・補正しない。隣接サイズの重複・内包は正常
/// （ゆらぎ判定側で処理する）。
library;

/// おむつのタイプ。シリーズによっては片方しか存在しない。
enum DiaperType { tape, pants }

/// タイプの表示名（テープ / パンツ）。
String diaperTypeLabel(DiaperType type) =>
    switch (type) { DiaperType.tape => 'テープ', DiaperType.pants => 'パンツ' };

/// バッジの3色（実在のパッケージから採った色。値の正は series.csv）。
class DiaperBadgeColors {
  const DiaperBadgeColors({
    required this.bg,
    required this.icon,
    required this.ring,
  });

  /// 内側の円の塗り（背景）。'#RRGGBB' 形式。
  final String bg;

  /// アイコンの塗りの色。'#RRGGBB' 形式。
  final String icon;

  /// 外周リング兼アイコン輪郭線の色。'#RRGGBB' 形式。
  final String ring;
}

/// 1サイズ分の公表体重帯（例：M 6〜11kg）。
class DiaperSizeBand {
  const DiaperSizeBand({
    required this.sizeLabel,
    required this.minKg,
    required this.maxKg,
  });

  /// 画面に出すサイズ名（例：新生児 / S / Mはいはい / ビッグより大きい）。
  final String sizeLabel;
  final double minKg;
  final double maxKg;
}

/// 体重（kg）の表示。整数なら小数を出さない（例：35 / 3.5）。
String diaperKgLabel(double v) =>
    v == v.roundToDouble() ? v.toInt().toString() : v.toStringAsFixed(1);

/// 体重帯の表示（例：9〜14kg）。
/// 下限が 0 の新生児サイズは 0 を出さず「〜5kg」の形にする。
String diaperRangeLabel(DiaperSizeBand band) {
  final max = '${diaperKgLabel(band.maxKg)}kg';
  if (band.minKg <= 0) return '〜$max';
  return '${diaperKgLabel(band.minKg)}〜$max';
}

/// 2段目：シリーズ（肌へのいちばん等）。タイプごとにサイズの「はしご」を持つ。
class DiaperSeries {
  const DiaperSeries({
    required this.id,
    required this.brandId,
    required this.displayName,
    this.displayNameTape,
    this.displayNamePants,
    required this.bands,
    required this.sourceUrl,
    required this.lastChecked,
    required this.badgeColors,
    this.badgeColorsTape,
    this.badgeColorsPants,
    this.badgeColorsBoy,
    this.badgeColorsGirl,
    this.category = '',
  });

  final String id;
  final String brandId;

  /// series_name（例：肌へのいちばん）。
  final String displayName;

  /// テープで商品名が変わる場合のみ（例：ムーニー）。null なら [displayName]。
  final String? displayNameTape;

  /// パンツで商品名が変わる場合のみ（例：ムーニーマン）。null なら [displayName]。
  final String? displayNamePants;

  /// タイプごとのサイズはしご（CSV の行順＝小さい順を保持）。
  /// 片方のタイプが存在しないシリーズでは、そのキー自体が無い。
  final Map<DiaperType, List<DiaperSizeBand>> bands;

  /// 出典（公式のサイズ表ページ）。
  final String sourceUrl;

  /// 最終確認日（ISO 形式 YYYY-MM-DD。生成スクリプトが正規化する）。
  final String lastChecked;

  /// バッジのベース3色（全シリーズ必須）。
  final DiaperBadgeColors badgeColors;

  /// テープとパンツで配色が別物のシリーズのみ（例：低刺激であんしん）。
  final DiaperBadgeColors? badgeColorsTape;
  final DiaperBadgeColors? badgeColorsPants;

  /// 男児色・女児色があるシリーズのみ（例：トレパンマン）。
  final DiaperBadgeColors? badgeColorsBoy;
  final DiaperBadgeColors? badgeColorsGirl;

  /// アイコン選択用のカテゴリ（night / swim / training / duration / 空）。
  /// 空＝通常品（diaper.svg）。
  final String category;

  /// バッジに使う3色を解決する。
  /// 優先順位：タイプ別上書き → 性別別上書き → ベース色。
  /// ただし「タイプ別」と「性別別」を同時に持つシリーズは生成スクリプトが
  /// 拒否するため（優先順位が未確認のため）、実際には競合しない。
  DiaperBadgeColors badgeColorsFor({DiaperType? type, bool? isBoy}) {
    final byType = switch (type) {
      DiaperType.tape => badgeColorsTape,
      DiaperType.pants => badgeColorsPants,
      null => null,
    };
    if (byType != null) return byType;
    final byGender = switch (isBoy) {
      true => badgeColorsBoy,
      false => badgeColorsGirl,
      null => null,
    };
    if (byGender != null) return byGender;
    return badgeColors;
  }

  DateTime get lastCheckedAt => DateTime.parse(lastChecked);

  /// このシリーズに存在するタイプ（enum 宣言順）。
  List<DiaperType> get availableTypes =>
      [for (final t in DiaperType.values) if (bands.containsKey(t)) t];

  /// テープ・パンツ両方が存在するか（タイプ選択画面を出すかの判定）。
  /// ハードコードせず、データに存在する type の種類数から動的に判定する。
  bool get hasBothTypes => availableTypes.length >= 2;

  /// タイプに応じたシリーズ表示名（タイプ別の商品名があればそちら）。
  String seriesNameFor(DiaperType type) => switch (type) {
        DiaperType.tape => displayNameTape ?? displayName,
        DiaperType.pants => displayNamePants ?? displayName,
      };

  /// 指定タイプのはしご（無ければ空リスト）。
  List<DiaperSizeBand> bandsFor(DiaperType type) => bands[type] ?? const [];
}

/// 1段目：ブランド（パンパース等）。選択UIには法人名を出さない。
class DiaperBrand {
  const DiaperBrand({
    required this.id,
    required this.displayName,
    this.makerName,
    required this.series,
  });

  final String id;

  /// brand_name（例：パンパース）。
  final String displayName;

  /// 法人名（例：P&G）。記録用。選択UIには出さない。
  final String? makerName;

  /// このブランドのシリーズ（CSV の行順を保つ）。
  final List<DiaperSeries> series;
}

/// カード等に出す表示名。原則「ブランド名 シリーズ名」。
/// シリーズ名がブランド名で始まる場合はシリーズ名だけを使う
/// （例：マミーポコ＋マミーポコ夜用 →「マミーポコ夜用」）。
String diaperDisplayName({
  required DiaperBrand brand,
  required DiaperSeries series,
  required DiaperType type,
}) {
  final seriesName = series.seriesNameFor(type);
  if (seriesName.startsWith(brand.displayName)) return seriesName;
  return '${brand.displayName} $seriesName';
}

/// series_id からシリーズを探す（無ければ null）。
DiaperSeries? findDiaperSeriesById(List<DiaperBrand> brands, String seriesId) {
  for (final brand in brands) {
    for (final series in brand.series) {
      if (series.id == seriesId) return series;
    }
  }
  return null;
}

/// brand_id からブランドを探す（無ければ null）。
DiaperBrand? findDiaperBrandById(List<DiaperBrand> brands, String brandId) {
  for (final brand in brands) {
    if (brand.id == brandId) return brand;
  }
  return null;
}

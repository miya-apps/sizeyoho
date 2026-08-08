import 'package:flutter/material.dart';
import 'package:intl/intl.dart';

import '../growth/growth_lms_2000.dart';
import '../growth/japanese_school_grade.dart';
import '../growth/lms_reference.dart';
import '../models/birthday_memory.dart';
import '../models/child_profile.dart';
import '../models/gender.dart';
import '../models/growth_record.dart';
import 'birthday_photo.dart';

// ── 履歴リスト専用：子テーマ（青/ピンク等）に一切依存しない固定スタイル ──

/// グラフの系列色と統一（身長＝青、体重＝オレンジ）。
const Color _heightColor = Color(0xFF1565C0);
const Color _weightColor = Color(0xFFE65100);

/// 履歴カード背景：必ず白（子テーマの surface / CardTheme を使わない）。
const Color _historyCardWhite = Colors.white;

/// ExpansionTile の罫線を物理的に消す shape（要件どおり `Border()` を直接使用）。
const ShapeBorder _expansionTileBorderless = Border();

/// タップ可能なアクションアイコン（編集・開閉矢印）の共通色。
Color get _actionIconColor => Colors.grey[700]!;

/// 履歴リスト subtree 用の固定 ThemeData。
/// MaterialApp の子テーマが切り替わっても、履歴 UI だけはこの Theme で描画する。
ThemeData _historyListTheme() {
  return ThemeData(
    useMaterial3: true,
    fontFamily: 'ZenMaruGothic',
    splashColor: Colors.black12,
    highlightColor: Colors.black12,
    scaffoldBackgroundColor: Colors.transparent,
    dividerTheme: DividerThemeData(
      color: Colors.grey.withValues(alpha: 0.2),
      thickness: 1,
      space: 1,
    ),
    expansionTileTheme: ExpansionTileThemeData(
      shape: const Border(),
      collapsedShape: const Border(),
      backgroundColor: Colors.transparent,
      collapsedBackgroundColor: Colors.transparent,
      iconColor: _actionIconColor,
      collapsedIconColor: _actionIconColor,
    ),
    cardTheme: CardThemeData(
      color: _historyCardWhite,
      surfaceTintColor: Colors.transparent,
      elevation: 0.5,
      shadowColor: Colors.black.withValues(alpha: 0.08),
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
    ),
    listTileTheme: ListTileThemeData(
      tileColor: Colors.transparent,
      selectedTileColor: Colors.transparent,
      iconColor: _actionIconColor,
    ),
    colorScheme: ColorScheme.fromSeed(
      seedColor: const Color(0xFF9E9E9E),
      brightness: Brightness.light,
    ).copyWith(
      surface: _historyCardWhite,
      onSurface: const Color(0xFF1A1A1A),
      onSurfaceVariant: const Color(0xFF757575),
    ),
  );
}

/// SDスコアの表示色（プラス＝青、マイナス＝赤/オレンジ）。
Color _sdScoreTextColor(double sd) {
  if (sd >= 0) return Colors.blue[700]!;
  return Colors.deepOrange[600]!;
}

/// SDスコアを「正なら + を付けて小数第1位」で整形する。
String _formatSd(double sd) {
  final s = sd.toStringAsFixed(1);
  return sd >= 0 ? '+$s SD' : '$s SD';
}

/// 測定日と生年月日から月齢を求め、LMS 基準で SD スコア（Z 値）を算出する。
double? _sdScore(
  LmsReference ref,
  DateTime birthDate,
  DateTime date,
  double? value,
) {
  if (value == null) return null;
  final months = date.difference(birthDate).inDays / 365.25 * 12;
  if (months < 0) return null;
  return ref.zScore(months, value);
}

/// 日本の年度（4月始まり）を返す。
int japaneseFiscalYear(DateTime date) =>
    date.month >= 4 ? date.year : date.year - 1;

/// 年度ごとにグループ化（年度の降順、各年度内は日付の降順）。
Map<int, List<GrowthRecord>> groupRecordsByFiscalYear(
  List<GrowthRecord> records,
) {
  final grouped = <int, List<GrowthRecord>>{};
  for (final record in records) {
    final fy = japaneseFiscalYear(record.date);
    grouped.putIfAbsent(fy, () => []).add(record);
  }
  for (final list in grouped.values) {
    list.sort((a, b) => b.date.compareTo(a.date));
  }
  return grouped;
}

/// リスト表示順（年度降順・各年度内は日付降順）のフラットな記録リスト。
List<GrowthRecord> flattenRecordsInDisplayOrder(List<GrowthRecord> records) {
  final grouped = groupRecordsByFiscalYear(records);
  final fiscalYears = grouped.keys.toList()..sort((a, b) => b.compareTo(a));
  return [
    for (final fy in fiscalYears) ...grouped[fy]!,
  ];
}

String _formatDate(DateTime d) =>
    '${d.year}/${d.month.toString().padLeft(2, '0')}/${d.day.toString().padLeft(2, '0')}';

/// 日本語ロケールの曜日略称（例：「木」）。
String _formatWeekdayJa(DateTime d) => DateFormat.E('ja').format(d);

/// 日付＋曜日（例：`2026/06/25 (木)`）。
String _formatDateWithWeekday(DateTime d) =>
    '${_formatDate(d)} (${_formatWeekdayJa(d)})';

// ── 誕生日マーカー ────────────────────────────────────────────────

/// 履歴リストに差し込む誕生日の目印。
/// 実測記録とは別物（グラフや統計には影響しない）で、日付は誕生日そのもの。
class _BirthdayMarker {
  const _BirthdayMarker({
    required this.age,
    required this.date,
    this.memory,
  });

  final int age;
  final DateTime date;
  final BirthdayMemory? memory;
}

/// 1歳〜現在の年齢までの誕生日マーカーを年度ごとにまとめる。
Map<int, List<_BirthdayMarker>> _birthdayMarkersByFiscalYear(
  ChildProfile child,
) {
  final today = DateTime.now();
  final result = <int, List<_BirthdayMarker>>{};
  for (var age = 1; age <= child.age; age++) {
    final date = DateTime(
      child.birthDate.year + age,
      child.birthDate.month,
      child.birthDate.day,
    );
    if (date.isAfter(today)) continue;
    BirthdayMemory? memory;
    for (final m in child.birthdayMemories) {
      if (m.age == age) memory = m;
    }
    result
        .putIfAbsent(japaneseFiscalYear(date), () => [])
        .add(_BirthdayMarker(age: age, date: date, memory: memory));
  }
  return result;
}

// ── 公開ウィジェット ──────────────────────────────────────────────

/// 成長記録の履歴リスト。
///
/// 子供（カラーテーマ）の切り替えに依存しない固定 UI。
/// [child.id] を Key に含め、切り替え時に強制リビルドする。
class GrowthHistoryList extends StatelessWidget {
  const GrowthHistoryList({
    super.key,
    required this.child,
    required this.onRecordTap,
    this.onBirthdayTap,
    this.isSelectionMode = false,
    this.selectedIndices = const [],
    this.onSelectionToggle,
    this.shrinkWrap = false,
    this.physics,
  });

  final ChildProfile child;
  final ValueChanged<GrowthRecord> onRecordTap;

  /// 誕生日マーカーのタップ（引数は年齢）。null ならマーカーを表示しない。
  final void Function(int age)? onBirthdayTap;

  final bool isSelectionMode;
  final List<int> selectedIndices;
  final ValueChanged<int>? onSelectionToggle;
  final bool shrinkWrap;
  final ScrollPhysics? physics;

  @override
  Widget build(BuildContext context) {
    // 子テーマを subtree から遮断し、履歴専用 Theme で包む。
    return Theme(
      key: ValueKey('history_theme_${child.id}'),
      data: _historyListTheme(),
      child: _GrowthHistoryListBody(
        key: ValueKey('history_body_${child.id}'),
        child: child,
        onRecordTap: onRecordTap,
        onBirthdayTap: onBirthdayTap,
        isSelectionMode: isSelectionMode,
        selectedIndices: selectedIndices,
        onSelectionToggle: onSelectionToggle,
        shrinkWrap: shrinkWrap,
        physics: physics,
      ),
    );
  }
}

class _GrowthHistoryListBody extends StatelessWidget {
  const _GrowthHistoryListBody({
    super.key,
    required this.child,
    required this.onRecordTap,
    required this.onBirthdayTap,
    required this.isSelectionMode,
    required this.selectedIndices,
    required this.onSelectionToggle,
    this.shrinkWrap = false,
    this.physics,
  });

  final ChildProfile child;
  final ValueChanged<GrowthRecord> onRecordTap;
  final void Function(int age)? onBirthdayTap;
  final bool isSelectionMode;
  final List<int> selectedIndices;
  final ValueChanged<int>? onSelectionToggle;
  final bool shrinkWrap;
  final ScrollPhysics? physics;

  @override
  Widget build(BuildContext context) {
    final grouped = groupRecordsByFiscalYear(child.growthRecords);
    final fiscalYears = grouped.keys.toList()..sort((a, b) => b.compareTo(a));
    // 期間比較の選択モード中は誕生日マーカーを出さない（記録選択の妨げになる）。
    final birthdayMarkers = (onBirthdayTap == null || isSelectionMode)
        ? const <int, List<_BirthdayMarker>>{}
        : _birthdayMarkersByFiscalYear(child);

    if (fiscalYears.isEmpty) {
      return Center(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(
              Icons.history_rounded,
              size: 48,
              color: Colors.grey.withValues(alpha: 0.35),
            ),
            const SizedBox(height: 12),
            Text(
              '記録がありません',
              style: TextStyle(color: Colors.grey[700]),
            ),
          ],
        ),
      );
    }

    final listChildren = <Widget>[const SizedBox(height: 16)];
    var indexOffset = 0;
    for (var i = 0; i < fiscalYears.length; i++) {
      final fy = fiscalYears[i];
      final records = grouped[fy]!;
      listChildren.add(
        _GrowthHistoryFiscalYearCard(
          key: ValueKey('history_fy_${child.id}_$fy'),
          fiscalYear: fy,
          child: child,
          initiallyExpanded: i == 0,
          records: records,
          birthdays: birthdayMarkers[fy] ?? const [],
          indexOffset: indexOffset,
          isSelectionMode: isSelectionMode,
          selectedIndices: selectedIndices,
          onSelectionToggle: onSelectionToggle,
          onRecordTap: onRecordTap,
          onBirthdayTap: onBirthdayTap,
        ),
      );
      indexOffset += records.length;
    }

    return ListView(
      key: ValueKey('history_listview_${child.id}'),
      shrinkWrap: shrinkWrap,
      physics: physics,
      padding: const EdgeInsets.only(bottom: 24),
      children: listChildren,
    );
  }
}

// ── 年度カード（Card + ExpansionTile） ────────────────────────────

class _GrowthHistoryFiscalYearCard extends StatelessWidget {
  const _GrowthHistoryFiscalYearCard({
    super.key,
    required this.fiscalYear,
    required this.child,
    required this.initiallyExpanded,
    required this.records,
    required this.birthdays,
    required this.indexOffset,
    required this.isSelectionMode,
    required this.selectedIndices,
    required this.onSelectionToggle,
    required this.onRecordTap,
    required this.onBirthdayTap,
  });

  final int fiscalYear;
  final ChildProfile child;
  final bool initiallyExpanded;
  final List<GrowthRecord> records;
  final List<_BirthdayMarker> birthdays;
  final int indexOffset;
  final bool isSelectionMode;
  final List<int> selectedIndices;
  final ValueChanged<int>? onSelectionToggle;
  final ValueChanged<GrowthRecord> onRecordTap;
  final void Function(int age)? onBirthdayTap;

  @override
  Widget build(BuildContext context) {
    final gradeLabel =
        JapaneseSchoolGrade.labelForFiscalYear(fiscalYear, child.birthDate);

    return Card(
      key: ValueKey('history_card_${child.id}_$fiscalYear'),
      margin: const EdgeInsets.fromLTRB(12, 0, 12, 12),
      // 背景色は必ず白固定（CardTheme / 子テーマの surface を使わない）。
      color: _historyCardWhite,
      surfaceTintColor: Colors.transparent,
      elevation: 0.5,
      shadowColor: Colors.black.withValues(alpha: 0.08),
      clipBehavior: Clip.antiAlias,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(12),
      ),
      child: ExpansionTile(
        key: ValueKey('history_tile_${child.id}_$fiscalYear'),
        initiallyExpanded: initiallyExpanded,
        tilePadding: const EdgeInsets.symmetric(horizontal: 20, vertical: 4),
        childrenPadding: EdgeInsets.zero,
        backgroundColor: Colors.transparent,
        collapsedBackgroundColor: Colors.transparent,
        // 要件1：ウィジェット本体に直接 Border() を指定しテーマ罫線を上書き。
        shape: _expansionTileBorderless,
        collapsedShape: _expansionTileBorderless,
        iconColor: _actionIconColor,
        collapsedIconColor: _actionIconColor,
        title: RichText(
          text: TextSpan(
            style: const TextStyle(
              fontSize: 14,
              fontWeight: FontWeight.w700,
              color: Color(0xFF1A1A1A),
            ),
            children: [
              TextSpan(text: '$fiscalYear年度'),
              TextSpan(
                text: '（$gradeLabel）',
                style: TextStyle(
                  fontWeight: FontWeight.w600,
                  color: Colors.grey[700],
                ),
              ),
            ],
          ),
        ),
        children: _buildRows(),
      ),
    );
  }

  /// 記録行と誕生日マーカーを日付降順でマージした行リストを作る。
  /// 同日の場合はマーカーを記録より上（新しい側）に置く。
  List<Widget> _buildRows() {
    final rows = <Widget>[];
    final markers = [...birthdays]..sort((a, b) => b.date.compareTo(a.date));
    var m = 0;

    void addMarker(_BirthdayMarker marker) {
      rows.add(
        _BirthdayMarkerTile(
          key: ValueKey('history_bday_${child.id}_${marker.age}'),
          marker: marker,
          onTap: onBirthdayTap == null
              ? null
              : () => onBirthdayTap!(marker.age),
        ),
      );
    }

    for (var i = 0; i < records.length; i++) {
      // この記録より新しい誕生日マーカーを先に差し込む。
      while (m < markers.length &&
          !markers[m].date.isBefore(records[i].date)) {
        addMarker(markers[m]);
        m++;
      }
      rows.add(
        _GrowthHistoryRecordTile(
          key: ValueKey(
            'history_rec_${child.id}_${records[i].date.toIso8601String()}',
          ),
          record: records[i],
          child: child,
          recordIndex: indexOffset + i,
          isSelectionMode: isSelectionMode,
          isSelected: selectedIndices.contains(indexOffset + i),
          onSelectionToggle: onSelectionToggle,
          onTap: () => onRecordTap(records[i]),
          isLast: i == records.length - 1 && m >= markers.length,
        ),
      );
    }
    // 最も古い記録より古い誕生日マーカー。
    while (m < markers.length) {
      addMarker(markers[m]);
      m++;
    }
    return rows;
  }
}

// ── 誕生日マーカー1行 ─────────────────────────────────────────────

class _BirthdayMarkerTile extends StatelessWidget {
  const _BirthdayMarkerTile({super.key, required this.marker, this.onTap});

  final _BirthdayMarker marker;
  final VoidCallback? onTap;

  @override
  Widget build(BuildContext context) {
    const accent = Color(0xFFE8837B);
    final memory = marker.memory;
    final photo = memory?.photoBytes;
    final sizeParts = <String>[
      if (memory?.heightCm != null)
        '${memory!.heightCm!.toStringAsFixed(1)}cm',
      if (memory?.weightKg != null) '${formatWeightKg(memory!.weightKg!)}kg',
    ];

    return ColoredBox(
      color: _historyCardWhite,
      child: Padding(
        padding: const EdgeInsets.fromLTRB(12, 4, 12, 4),
        child: Material(
          color: const Color(0xFFFDF1EC),
          borderRadius: BorderRadius.circular(10),
          child: InkWell(
            onTap: onTap,
            borderRadius: BorderRadius.circular(10),
            child: Padding(
              padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
              child: Row(
                children: [
                  const Text('🎂', style: TextStyle(fontSize: 15)),
                  const SizedBox(width: 8),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          '${marker.age}歳のお誕生日 '
                          '（${_formatDate(marker.date)}）',
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                          style: const TextStyle(
                            fontSize: 12.5,
                            fontWeight: FontWeight.w700,
                            color: Color(0xFF9C4A3E),
                          ),
                        ),
                        if (sizeParts.isNotEmpty ||
                            (memory?.note?.isNotEmpty ?? false))
                          Text(
                            [
                              if (sizeParts.isNotEmpty) sizeParts.join('・'),
                              if (memory?.note?.isNotEmpty ?? false)
                                memory!.note!,
                            ].join('　'),
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                            style: TextStyle(
                              fontSize: 11.5,
                              color: Colors.grey[700],
                            ),
                          ),
                      ],
                    ),
                  ),
                  const SizedBox(width: 8),
                  if (photo != null)
                    SizedBox(
                      width: 30,
                      height: 30,
                      child: BirthdayPhoto(
                        bytes: photo,
                        alignX: memory?.photoAlignX ?? 0,
                        alignY: memory?.photoAlignY ?? 0,
                        scale: memory?.photoScale ?? 1.0,
                        borderRadius: 6,
                      ),
                    )
                  else
                    Text(
                      '思い出を残す',
                      style: TextStyle(
                        fontSize: 12.5,
                        fontWeight: FontWeight.w700,
                        // 淡いテーマ色のままでは白背景で読みにくいため、
                        // 黒に寄せた濃色にする。
                        color: Color.lerp(accent, Colors.black, 0.35),
                      ),
                    ),
                  Icon(Icons.chevron_right_rounded,
                      size: 16, color: Colors.grey[500]),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }
}

// ── 記録1行 ──────────────────────────────────────────────────────

class _GrowthHistoryRecordTile extends StatelessWidget {
  const _GrowthHistoryRecordTile({
    super.key,
    required this.record,
    required this.child,
    required this.recordIndex,
    required this.isSelectionMode,
    required this.isSelected,
    required this.onSelectionToggle,
    required this.onTap,
    required this.isLast,
  });

  final GrowthRecord record;
  final ChildProfile child;
  final int recordIndex;
  final bool isSelectionMode;
  final bool isSelected;
  final ValueChanged<int>? onSelectionToggle;
  final VoidCallback onTap;
  final bool isLast;

  void _handleTap() {
    if (isSelectionMode) {
      onSelectionToggle?.call(recordIndex);
    } else {
      onTap();
    }
  }

  @override
  Widget build(BuildContext context) {
    final isBoy = child.gender == Gender.male;

    final h = record.heightCm;
    final w = record.weightKg;
    final hSd = _sdScore(
      GrowthLms2000.heightRef(isBoy: isBoy),
      child.birthDate,
      record.date,
      h,
    );
    final wSd = _sdScore(
      GrowthLms2000.weightRef(isBoy: isBoy),
      child.birthDate,
      record.date,
      w,
    );

    final blocks = <Widget>[
      if (h != null)
        _metricBlock(
          icon: Icons.straighten,
          color: _heightColor,
          value: h.toStringAsFixed(1),
          unit: 'cm',
          sd: hSd,
        ),
      if (w != null)
        _metricBlock(
          icon: Icons.monitor_weight_outlined,
          color: _weightColor,
          // 10g 単位の端数があるときだけ小数2桁で表示する。
          value: formatWeightKg(w),
          unit: 'kg',
          sd: wSd,
        ),
    ];

    return ColoredBox(
      // 行背景は常に白（ゼブラ・テーマ surface によるグレー化を防止）。
      color: _historyCardWhite,
      child: Column(
        children: [
          Material(
            type: MaterialType.transparency,
            color: Colors.transparent,
            child: InkWell(
              onTap: _handleTap,
              splashColor: Colors.black12,
              highlightColor: Colors.black12,
              child: Padding(
                padding: EdgeInsets.fromLTRB(
                  isSelectionMode ? 8 : 20,
                  12,
                  16,
                  12,
                ),
                child: Row(
                  crossAxisAlignment: CrossAxisAlignment.center,
                  children: [
                    if (isSelectionMode) ...[
                      Checkbox(
                        value: isSelected,
                        onChanged: (_) => onSelectionToggle?.call(recordIndex),
                        materialTapTargetSize: MaterialTapTargetSize.shrinkWrap,
                        visualDensity: VisualDensity.compact,
                      ),
                      const SizedBox(width: 4),
                    ],
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            _formatDateWithWeekday(record.date),
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                            style: TextStyle(
                              fontSize: 13,
                              fontWeight: FontWeight.w500,
                              color: Colors.grey[800],
                            ),
                          ),
                          const SizedBox(height: 6),
                          SizedBox(
                            width: double.infinity,
                            child: FittedBox(
                              fit: BoxFit.scaleDown,
                              child: Row(
                                mainAxisAlignment: MainAxisAlignment.center,
                                mainAxisSize: MainAxisSize.min,
                                children: [
                                  for (var i = 0; i < blocks.length; i++) ...[
                                    if (i > 0) const SizedBox(width: 24),
                                    blocks[i],
                                  ],
                                ],
                              ),
                            ),
                          ),
                        ],
                      ),
                    ),
                    if (!isSelectionMode) ...[
                      const SizedBox(width: 8),
                      Icon(
                        Icons.edit,
                        size: 18,
                        color: _actionIconColor,
                      ),
                    ],
                  ],
                ),
              ),
            ),
          ),
          // 要件3：index == length - 1（isLast）のとき Divider を表示しない。
          if (!isLast)
            Divider(
              height: 1,
              indent: 16,
              endIndent: 16,
              color: Colors.grey.withValues(alpha: 0.2),
            ),
        ],
      ),
    );
  }

  Widget _metricBlock({
    required IconData icon,
    required Color color,
    required String value,
    required String unit,
    required double? sd,
  }) {
    return Row(
      mainAxisSize: MainAxisSize.min,
      crossAxisAlignment: CrossAxisAlignment.center,
      children: [
        Icon(icon, size: 18, color: color),
        const SizedBox(width: 4),
        Text.rich(
          TextSpan(
            children: [
              TextSpan(
                text: value,
                style: const TextStyle(
                  fontSize: 16,
                  fontWeight: FontWeight.bold,
                  color: Color(0xFF1A1A1A),
                ),
              ),
              TextSpan(
                text: ' $unit',
                style: const TextStyle(
                  fontSize: 12,
                  fontWeight: FontWeight.w400,
                  color: Color(0xFF1A1A1A),
                ),
              ),
              if (sd != null)
                TextSpan(
                  text: '  (${_formatSd(sd)})',
                  style: TextStyle(
                    fontSize: 11,
                    fontWeight: FontWeight.w500,
                    color: _sdScoreTextColor(sd),
                  ),
                ),
            ],
          ),
          maxLines: 1,
          softWrap: false,
        ),
      ],
    );
  }
}

import 'package:flutter/material.dart';
import 'package:intl/intl.dart';

import '../app/adaptive_layout.dart';
import '../models/child_profile.dart';
import '../models/growth_record.dart';
import 'measurement_wheels.dart';

/// 時刻（時・分・秒）を完全に無視し「年・月・日」だけで同一日かを判定する。
bool isSameCalendarDay(DateTime a, DateTime b) =>
    a.year == b.year && a.month == b.month && a.day == b.day;

/// 成長記録の入力フォーム（追加・編集 共通）を表示する。
///
/// 追加も編集も「日付のハコにデータがあるか」だけで挙動が決まる。
/// - [editingRecord] を渡すと、その記録を編集モードで開く（履歴の編集から呼ぶ場合）。
/// - [initialDate] のみ渡すと、その日付で起動する。省略時は今日（＋ボタンからの新規入力）。
Future<void> showGrowthRecordSheet({
  required BuildContext context,
  required ChildProfile child,
  required ValueChanged<ChildProfile> onSave,
  DateTime? initialDate,
  GrowthRecord? editingRecord,
}) {
  final form = _GrowthRecordSheet(
    child: child,
    onSave: onSave,
    initialDate: editingRecord?.date ?? initialDate ?? DateTime.now(),
    editingRecord: editingRecord,
    rootContext: context,
  );
  final background = Theme.of(context).colorScheme.surfaceContainerLowest;

  // 大画面（タブレット・横持ち等）ではボトムシートが横に間延びして
  // 手元から遠くなるため、中央のダイアログで表示する。
  // スマホでは片手で扱いやすい従来のボトムシートを維持する。
  if (MediaQuery.sizeOf(context).width >= 600) {
    return showDialog<void>(
      context: context,
      builder: (dialogCtx) => Dialog(
        backgroundColor: background,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(24),
        ),
        child: ConstrainedBox(
          constraints: const BoxConstraints(maxWidth: 560),
          child: SingleChildScrollView(child: form),
        ),
      ),
    );
  }

  return showModalBottomSheet<void>(
    context: context,
    isScrollControlled: true,
    showDragHandle: true,
    backgroundColor: background,
    builder: (sheetCtx) => form,
  );
}

class _GrowthRecordSheet extends StatefulWidget {
  const _GrowthRecordSheet({
    required this.child,
    required this.onSave,
    required this.initialDate,
    required this.rootContext,
    this.editingRecord,
  });

  final ChildProfile child;
  final ValueChanged<ChildProfile> onSave;
  final DateTime initialDate;
  final GrowthRecord? editingRecord;

  /// SnackBar 表示用（シート閉鎖後も生存する画面側の context）。
  final BuildContext rootContext;

  @override
  State<_GrowthRecordSheet> createState() => _GrowthRecordSheetState();
}

class _GrowthRecordSheetState extends State<_GrowthRecordSheet> {
  late final List<GrowthRecord> _records;
  late DateTime _recordDate;

  /// 編集対象レコードの ID（鉛筆から開いた場合に設定。日付変更後も不変）。
  String? _editingRecordId;

  // 該当日にデータが無いときのプリセット（前回値 → 既定値）。
  late final double _defaultH;
  late final double _defaultW;

  bool _heightEnabled = true;
  bool _weightEnabled = true;

  /// 身長・体重ホイールの選択 index。
  late int _hIndex;
  late int _wIndex;

  late final FixedExtentScrollController _hCtrl;
  late final FixedExtentScrollController _wCtrl;

  @override
  void initState() {
    super.initState();
    _records = List<GrowthRecord>.from(widget.child.growthRecords)
      ..sort((a, b) => b.date.compareTo(a.date));
    final latest = _records.isNotEmpty ? _records.first : null;
    _defaultH = latest?.heightCm ?? 80.0;
    _defaultW = latest?.weightKg ?? 10.0;

    _recordDate = widget.initialDate;
    _editingRecordId = widget.editingRecord?.id;
    // 起動時点で選択日のデータをプリロードしてトグル／数値へ反映する。
    if (widget.editingRecord != null) {
      _loadFromRecord(widget.editingRecord!);
    } else {
      _loadForDate(_recordDate);
    }

    _hCtrl = FixedExtentScrollController(initialItem: _hIndex);
    _wCtrl = FixedExtentScrollController(initialItem: _wIndex);
  }

  @override
  void dispose() {
    _hCtrl.dispose();
    _wCtrl.dispose();
    super.dispose();
  }

  /// 現在入力中の身長（cm）。
  double get _currentHeightCm => heightCmAtWheelIndex(_hIndex);

  /// 現在入力中の体重（kg・10kg までは 10g 精度）。
  double get _currentWeightKg => weightKgAtWheelIndex(_wIndex);

  GrowthRecord? _findSameDay(DateTime date) {
    for (final r in _records) {
      if (isSameCalendarDay(r.date, date)) return r;
    }
    return null;
  }

  /// 指定レコードの値をフォームへ反映する（編集起動時）。
  void _loadFromRecord(GrowthRecord record) {
    _heightEnabled = record.heightCm != null;
    _weightEnabled = record.weightKg != null;
    _hIndex = heightWheelIndexOf(record.heightCm ?? _defaultH);
    _wIndex = weightWheelIndexOf(record.weightKg ?? _defaultW);
  }

  /// 選択日の既存データを読み込み、トグル状態とピッカー値を決定する。
  /// （フィールドのみ更新。コントローラ同期は [_syncControllers] で行う）
  void _loadForDate(DateTime date) {
    final existing = _findSameDay(date);

    // 既存があれば「値を持つ項目だけON」、無ければ通常初期状態（両方ON）。
    _heightEnabled = existing != null ? existing.heightCm != null : true;
    _weightEnabled = existing != null ? existing.weightKg != null : true;

    _hIndex = heightWheelIndexOf(existing?.heightCm ?? _defaultH);
    _wIndex = weightWheelIndexOf(existing?.weightKg ?? _defaultW);
  }

  void _syncControllers() {
    _hCtrl.jumpToItem(_hIndex);
    _wCtrl.jumpToItem(_wIndex);
  }

  Future<void> _pickDate() async {
    final picked = await showDatePicker(
      context: context,
      initialDate: _recordDate,
      firstDate: DateTime(2000),
      lastDate: DateTime.now(),
      helpText: '測定日を選択',
      cancelText: 'キャンセル',
      confirmText: '確定',
    );
    if (picked == null) return;
    setState(() {
      _recordDate = picked;
      // 日付変更時も同様に既存データを再読込してUIへ反映。
      _loadForDate(picked);
    });
    _syncControllers();
  }

  void _save() {
    final h = _heightEnabled ? _currentHeightCm : null;
    final w = _weightEnabled ? _currentWeightKg : null;

    final sameDayExisting = _findSameDay(_recordDate);
    final recordId = _editingRecordId ??
        sameDayExisting?.id ??
        GrowthRecord.generateId();

    final record = GrowthRecord(
      id: recordId,
      date: _recordDate,
      heightCm: h,
      weightKg: w,
    );

    final next = List<GrowthRecord>.from(_records)
      // 編集で日付を変えた場合、同一 ID の古い行だけ更新し二重登録を防ぐ。
      ..removeWhere(
        (r) =>
            r.id != record.id &&
            isSameCalendarDay(r.date, _recordDate),
      );

    final idx = next.indexWhere((r) => r.id == record.id);
    if (idx >= 0) {
      next[idx] = record;
    } else {
      next.add(record);
    }
    next.sort((a, b) => b.date.compareTo(a.date));

    // 新しいリストインスタンスで状態更新 → 履歴/グラフが即時再描画される。
    widget.onSave(widget.child.copyWith(growthRecords: next));
    Navigator.pop(context);
    ScaffoldMessenger.of(widget.rootContext).showSnackBar(
      const SnackBar(
        content: Text('成長記録を保存しました'),
        behavior: SnackBarBehavior.floating,
      ),
    );
  }

  Future<void> _delete() async {
    final scheme = Theme.of(context).colorScheme;
    // async gap 後の BuildContext 参照を避けるため、messenger は事前に取得する。
    final rootMessenger = ScaffoldMessenger.of(widget.rootContext);
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (dialogCtx) => AlertDialog(
        title: const Text('記録を削除'),
        content: const Text('この日の記録を削除しますか？'),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(dialogCtx, false),
            child: const Text('キャンセル'),
          ),
          TextButton(
            onPressed: () => Navigator.pop(dialogCtx, true),
            child: Text('削除', style: TextStyle(color: scheme.error)),
          ),
        ],
      ),
    );
    if (confirmed != true) return;

    final next = List<GrowthRecord>.from(_records);
    if (_editingRecordId != null) {
      next.removeWhere((r) => r.id == _editingRecordId);
    } else {
      next.removeWhere((r) => isSameCalendarDay(r.date, _recordDate));
    }
    widget.onSave(widget.child.copyWith(growthRecords: next));
    if (!mounted) return;
    Navigator.pop(context);
    rootMessenger.showSnackBar(
      const SnackBar(
        content: Text('成長記録を削除しました'),
        behavior: SnackBarBehavior.floating,
      ),
    );
  }

  /// 大画面ではピッカー類をひと回り拡大する（最大1.3倍）。
  double get _uiScale => uiScaleForWidth(MediaQuery.sizeOf(context).width);

  /// 体重ピッカー下部の g 換算表示。
  /// 母子手帳の表記が g の乳児期（10kg 未満）だけ小さく併記する。
  /// 10kg を跨いだ瞬間にレイアウトが動かないよう、高さは常に確保しておく。
  Widget _weightFooter(ColorScheme scheme) {
    final kg = _currentWeightKg;
    final show = kg < weightGramNoteMaxKg;
    final s = _uiScale;
    return SizedBox(
      height: 16 * s,
      child: show
          ? Text(
              '= ${NumberFormat('#,##0').format((kg * 1000).round())} g',
              style: TextStyle(
                fontSize: 11 * s,
                fontWeight: FontWeight.w600,
                color: scheme.onSurfaceVariant.withValues(alpha: 0.8),
              ),
            )
          : null,
    );
  }

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    final canSave = _heightEnabled || _weightEnabled;
    // 編集モード／削除ボタン：編集対象 ID があるか、選択日に既存データがあるか。
    final hasExisting =
        _editingRecordId != null || _findSameDay(_recordDate) != null;

    return Padding(
      padding: EdgeInsets.fromLTRB(
        24,
        8,
        24,
        MediaQuery.viewInsetsOf(context).bottom + 32,
      ),
      // 大画面では測定日などの入力欄が横に間延びしないよう
      // 幅を制限して中央寄せする。heightFactor: 1 で縦は中身の高さだけに
      // とどめる（縦いっぱいに広がるとキャンセル操作がしづらいため）。
      child: Center(
        heightFactor: 1,
        child: ConstrainedBox(
          constraints: const BoxConstraints(maxWidth: 480),
          child: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            hasExisting ? '📏 成長記録を編集' : '📏 成長記録を追加',
            style: TextStyle(
              fontSize: 16,
              fontWeight: FontWeight.bold,
              color: scheme.onSurface,
            ),
          ),
          Text(
            widget.child.displayName,
            style: TextStyle(
              fontSize: 13,
              color: scheme.onSurfaceVariant,
            ),
          ),
          const SizedBox(height: 16),
          InkWell(
            borderRadius: BorderRadius.circular(4),
            onTap: _pickDate,
            child: InputDecorator(
              decoration: const InputDecoration(
                labelText: '測定日',
                border: OutlineInputBorder(),
                suffixIcon: Icon(Icons.calendar_month_rounded),
              ),
              child: Text(
                '${_recordDate.year}年${_recordDate.month}月${_recordDate.day}日',
              ),
            ),
          ),
          const SizedBox(height: 20),
          // 身長・体重のピッカーは中央寄せ（大画面では _uiScale で拡大）。
          Row(
            mainAxisAlignment: MainAxisAlignment.center,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              // 身長：0.1cm 刻みの実数値ホイール（前回値プリセット済み）。
              MeasurementPickerColumn(
                label: '身長',
                unit: 'cm',
                wheel: MeasurementValueWheel(
                  controller: _hCtrl,
                  itemCount: heightWheelItemCount,
                  labelAt: heightWheelLabelAt,
                  onChanged: (i) => _hIndex = i,
                  scale: _uiScale,
                ),
                enabled: _heightEnabled,
                onToggle: (v) => setState(() => _heightEnabled = v),
                toggleColor: widget.child.themeColor,
                scale: _uiScale,
              ),
              const SizedBox(width: 20),
              // 体重：10kg までは 10g 刻み、以降は 100g 刻みの実数値ホイール。
              // g 換算表示を追従させるため onChanged で setState する。
              MeasurementPickerColumn(
                label: '体重',
                unit: 'kg',
                wheel: MeasurementValueWheel(
                  controller: _wCtrl,
                  itemCount: weightWheelItemCount,
                  labelAt: weightWheelLabelAt,
                  onChanged: (i) => setState(() => _wIndex = i),
                  scale: _uiScale,
                ),
                enabled: _weightEnabled,
                onToggle: (v) => setState(() => _weightEnabled = v),
                toggleColor: widget.child.themeColor,
                footer: _weightFooter(scheme),
                scale: _uiScale,
              ),
            ],
          ),
          const SizedBox(height: 24),
          FilledButton.icon(
            // 両方OFF（空データ）のときだけ非活性。片方でもONなら保存可能。
            onPressed: canSave ? _save : null,
            icon: const Icon(Icons.save_rounded),
            label: const Text('記録を保存'),
            style: FilledButton.styleFrom(
              minimumSize: const Size.fromHeight(48),
            ),
          ),
          // 削除ボタンは「その日付にデータが存在する」ときだけ表示する。
          // ミニマルに、赤いゴミ箱アイコン単体を中央配置する。
          if (hasExisting) ...[
            const SizedBox(height: 8),
            Center(
              child: IconButton(
                onPressed: _delete,
                icon: const Icon(Icons.delete),
                color: Colors.red,
                tooltip: 'この記録を削除',
              ),
            ),
          ],
        ],
          ),
        ),
      ),
    );
  }
}

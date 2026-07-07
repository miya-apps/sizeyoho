import 'package:flutter/material.dart';

import '../app/adaptive_layout.dart';
import '../growth/growth_period_summary.dart';
import '../models/child_profile.dart';
import '../models/growth_record.dart';
import '../widgets/birthday_memory_edit_dialog.dart';
import '../widgets/growth_record_add_sheet.dart';
import '../widgets/growth_history_list.dart';
import '../widgets/growth_summary_sheet.dart';

export '../widgets/growth_history_list.dart'
    show
        flattenRecordsInDisplayOrder,
        groupRecordsByFiscalYear,
        japaneseFiscalYear;

/// 成長記録の履歴画面。
///
/// リスト UI は [GrowthHistoryList] に集約。
/// 子テーマ切替に依存しない固定デザインを、どの子供でも同じ見た目で描画する。
class RecordHistoryScreen extends StatefulWidget {
  const RecordHistoryScreen({
    super.key,
    required this.child,
    required this.onUpdateChild,
  });

  final ChildProfile child;
  final ValueChanged<ChildProfile> onUpdateChild;

  @override
  State<RecordHistoryScreen> createState() => RecordHistoryScreenState();
}

class RecordHistoryScreenState extends State<RecordHistoryScreen> {
  bool _isSelectionMode = false;
  final List<int> _selectedIndices = [];

  @override
  void didUpdateWidget(RecordHistoryScreen oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.child.id != widget.child.id) {
      _isSelectionMode = false;
      _selectedIndices.clear();
    }
  }

  void _openSheet(BuildContext context, GrowthRecord editing) {
    showGrowthRecordSheet(
      context: context,
      child: widget.child,
      editingRecord: editing,
      onSave: widget.onUpdateChild,
    );
  }

  void _enterSelectionMode() {
    setState(() {
      _isSelectionMode = true;
      _selectedIndices.clear();
    });
  }

  void handleSummaryDialogResult(GrowthSummaryDialogResult? result) {
    if (!mounted) return;
    if (result == GrowthSummaryDialogResult.pickAnotherPeriod) {
      _enterSelectionMode();
    } else {
      _resetSelectionMode();
    }
  }

  void _cancelSelectionMode() {
    _resetSelectionMode();
  }

  void _resetSelectionMode() {
    setState(() {
      _isSelectionMode = false;
      _selectedIndices.clear();
    });
  }

  Future<void> _compareSelected() async {
    if (_selectedIndices.length != 2) return;

    final flat = flattenRecordsInDisplayOrder(widget.child.growthRecords);
    final first = _selectedIndices[0];
    final second = _selectedIndices[1];
    if (first < 0 ||
        first >= flat.length ||
        second < 0 ||
        second >= flat.length) {
      return;
    }

    final summary = GrowthPeriodSummaryCalculator.computeBetween(
      child: widget.child,
      recordA: flat[first],
      recordB: flat[second],
    );

    final result = await showGrowthComparisonSummarySheet(
      context: context,
      child: widget.child,
      summary: summary,
    );

    handleSummaryDialogResult(result);
  }

  void _toggleSelection(int index) {
    setState(() {
      if (_selectedIndices.contains(index)) {
        _selectedIndices.remove(index);
      } else if (_selectedIndices.length >= 2) {
        _selectedIndices.removeAt(0);
        _selectedIndices.add(index);
      } else {
        _selectedIndices.add(index);
      }
    });
  }

  @override
  Widget build(BuildContext context) {
    final showCompareButton = _isSelectionMode && _selectedIndices.length == 2;

    return Scaffold(
      backgroundColor: Colors.transparent,
      body: SafeArea(
        bottom: false,
        child: SingleChildScrollView(
          padding: const EdgeInsets.only(bottom: 96),
          // 大画面ではリスト行が横に間延びしないよう幅を制限して中央寄せする。
          child: Center(
            child: ConstrainedBox(
              constraints: const BoxConstraints(maxWidth: kContentMaxWidth),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  if (_isSelectionMode)
                    Padding(
                      padding: const EdgeInsets.fromLTRB(8, 4, 8, 0),
                      child: Row(
                        children: [
                          Expanded(
                            child: Text(
                              '期間を選択（最大2件）',
                              style: TextStyle(
                                fontSize: 15,
                                fontWeight: FontWeight.w600,
                                color: Colors.grey[800],
                              ),
                            ),
                          ),
                          TextButton(
                            onPressed: _cancelSelectionMode,
                            child: Text(
                              'キャンセル',
                              style: TextStyle(
                                color: Colors.grey[700],
                                fontWeight: FontWeight.w600,
                              ),
                            ),
                          ),
                        ],
                      ),
                    ),
                  GrowthHistoryList(
                    key: ValueKey('record_history_screen_${widget.child.id}'),
                    child: widget.child,
                    isSelectionMode: _isSelectionMode,
                    selectedIndices: _selectedIndices,
                    onSelectionToggle: _toggleSelection,
                    onRecordTap: (record) => _openSheet(context, record),
                    // 誕生日マーカーのタップで思い出（写真・サイズ・メモ）を編集。
                    onBirthdayTap: (age) => showBirthdayMemoryEditDialog(
                      context: context,
                      child: widget.child,
                      age: age,
                      onUpdate: widget.onUpdateChild,
                    ),
                    shrinkWrap: true,
                    physics: const NeverScrollableScrollPhysics(),
                  ),
                  if (showCompareButton)
                    Padding(
                      padding: const EdgeInsets.fromLTRB(16, 8, 16, 12),
                      child: SizedBox(
                        width: double.infinity,
                        child: FilledButton.icon(
                          onPressed: _compareSelected,
                          icon: const Icon(Icons.compare_arrows_rounded),
                          label: const Text('比較する'),
                          style: FilledButton.styleFrom(
                            minimumSize: const Size.fromHeight(48),
                          ),
                        ),
                      ),
                    ),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }
}

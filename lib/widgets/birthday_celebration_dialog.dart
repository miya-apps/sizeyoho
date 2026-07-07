import 'package:flutter/material.dart';

import '../models/birthday_memory.dart';
import '../models/child_profile.dart';
import '../models/growth_record.dart';
import 'birthday_memory_edit_dialog.dart';
import 'birthday_photo.dart';

/// お誕生日のお祝いダイアログを表示する。
///
/// - この1年での身長・体重の伸びをまとめて表示する（計算できる場合のみ）
/// - 思い出（写真・サイズ・メモ）を残せる（年齢ごとに1件、あとから差し替え可）
/// - 「今後表示しない」でお祝い表示自体をオフにできる
Future<void> showBirthdayCelebrationDialog({
  required BuildContext context,
  required ChildProfile child,
  required int age,
  required Future<void> Function(ChildProfile) onUpdateChild,
}) async {
  final scheme = Theme.of(context).colorScheme;
  final summary = _yearGrowthSummary(child);

  // ダイアログ内での更新を反映するためのローカル参照。
  var current = child;

  BirthdayMemory? memoryOf(ChildProfile c) {
    for (final m in c.birthdayMemories) {
      if (m.age == age) return m;
    }
    return null;
  }

  await showDialog<void>(
    context: context,
    builder: (dialogContext) => StatefulBuilder(
      builder: (ctx, setS) {
        final memory = memoryOf(current);
        final photo = memory?.photoBytes;
        final sizeParts = <String>[
          if (memory?.heightCm != null)
            '${memory!.heightCm!.toStringAsFixed(1)}cm',
          if (memory?.weightKg != null)
            '${formatWeightKg(memory!.weightKg!)}kg',
        ];

        Future<void> editMemory() async {
          await showBirthdayMemoryEditDialog(
            context: ctx,
            child: current,
            age: age,
            onUpdate: (updated) {
              current = updated;
              onUpdateChild(updated);
              setS(() {});
            },
          );
        }

        return Dialog(
          backgroundColor: Colors.white,
          shape:
              RoundedRectangleBorder(borderRadius: BorderRadius.circular(24)),
          child: ConstrainedBox(
            constraints: const BoxConstraints(maxWidth: 380),
            child: SingleChildScrollView(
              padding: const EdgeInsets.fromLTRB(22, 24, 22, 12),
              child: Column(
                mainAxisSize: MainAxisSize.min,
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  const Text('🎂',
                      textAlign: TextAlign.center,
                      style: TextStyle(fontSize: 44)),
                  const SizedBox(height: 8),
                  Text(
                    current.displayName,
                    textAlign: TextAlign.center,
                    style: const TextStyle(
                      fontSize: 18,
                      fontWeight: FontWeight.w700,
                      color: Color(0xFF333333),
                    ),
                  ),
                  const SizedBox(height: 2),
                  Text(
                    '$age歳のお誕生日おめでとう！🎉',
                    textAlign: TextAlign.center,
                    style: TextStyle(
                      fontSize: 16,
                      fontWeight: FontWeight.w700,
                      color: scheme.primary,
                    ),
                  ),
                  if (summary != null) ...[
                    const SizedBox(height: 14),
                    Container(
                      padding: const EdgeInsets.symmetric(
                          horizontal: 14, vertical: 10),
                      decoration: BoxDecoration(
                        color: scheme.primary.withValues(alpha: 0.08),
                        borderRadius: BorderRadius.circular(12),
                      ),
                      child: Text(
                        summary,
                        textAlign: TextAlign.center,
                        style: TextStyle(
                          fontSize: 13,
                          height: 1.5,
                          fontWeight: FontWeight.w600,
                          color: scheme.primary,
                        ),
                      ),
                    ),
                  ],
                  const SizedBox(height: 14),
                  if (memory != null) ...[
                    if (photo != null)
                      // アルバム・編集画面と同じ正方形＋切り取り位置で表示。
                      Center(
                        child: SizedBox(
                          width: 220,
                          child: BirthdayPhoto(
                            bytes: photo,
                            alignX: memory.photoAlignX,
                            alignY: memory.photoAlignY,
                            scale: memory.photoScale,
                            borderRadius: 14,
                          ),
                        ),
                      ),
                    if (sizeParts.isNotEmpty) ...[
                      const SizedBox(height: 8),
                      Text(
                        sizeParts.join('・'),
                        textAlign: TextAlign.center,
                        style: const TextStyle(
                          fontSize: 13.5,
                          fontWeight: FontWeight.w700,
                          color: Color(0xFF333333),
                        ),
                      ),
                    ],
                    if (memory.note != null && memory.note!.isNotEmpty) ...[
                      const SizedBox(height: 4),
                      Text(
                        memory.note!,
                        textAlign: TextAlign.center,
                        style: TextStyle(
                          fontSize: 12.5,
                          height: 1.5,
                          color: Colors.grey[700],
                        ),
                      ),
                    ],
                    TextButton.icon(
                      onPressed: editMemory,
                      icon: const Icon(Icons.edit_outlined, size: 16),
                      label: const Text('思い出を編集（写真・サイズ・メモ）'),
                    ),
                  ] else
                    // 思い出がまだない場合：点線枠の追加エリア
                    Material(
                      color: scheme.primary.withValues(alpha: 0.04),
                      borderRadius: BorderRadius.circular(14),
                      child: InkWell(
                        borderRadius: BorderRadius.circular(14),
                        onTap: editMemory,
                        child: Container(
                          padding: const EdgeInsets.symmetric(vertical: 22),
                          decoration: BoxDecoration(
                            borderRadius: BorderRadius.circular(14),
                            border: Border.all(
                              color: scheme.primary.withValues(alpha: 0.35),
                              width: 1.2,
                            ),
                          ),
                          child: Column(
                            children: [
                              Icon(Icons.add_a_photo_outlined,
                                  size: 28, color: scheme.primary),
                              const SizedBox(height: 8),
                              Text(
                                '思い出を残す（写真・サイズ・メモ）',
                                style: TextStyle(
                                  fontSize: 13.5,
                                  fontWeight: FontWeight.w700,
                                  color: scheme.primary,
                                ),
                              ),
                              const SizedBox(height: 2),
                              Text(
                                '毎年のお誕生日に1つずつ記録できます',
                                style: TextStyle(
                                  fontSize: 11.5,
                                  color: Colors.grey[600],
                                ),
                              ),
                            ],
                          ),
                        ),
                      ),
                    ),
                  const SizedBox(height: 8),
                  Text(
                    '残した思い出は 履歴の「思い出」ボタンからいつでも見返せます',
                    textAlign: TextAlign.center,
                    style: TextStyle(fontSize: 11, color: Colors.grey[500]),
                  ),
                  const SizedBox(height: 4),
                  Row(
                    children: [
                      TextButton(
                        onPressed: () async {
                          await onUpdateChild(current.copyWith(
                              birthdayCelebrationEnabled: false));
                          if (ctx.mounted) Navigator.of(ctx).pop();
                        },
                        child: Text(
                          '今後表示しない',
                          style:
                              TextStyle(fontSize: 12, color: Colors.grey[500]),
                        ),
                      ),
                      const Spacer(),
                      FilledButton(
                        onPressed: () => Navigator.of(ctx).pop(),
                        child: const Text('閉じる'),
                      ),
                    ],
                  ),
                ],
              ),
            ),
          ),
        );
      },
    ),
  );
}

/// 直近1年での身長・体重の伸びをまとめた文言を返す。
/// 約1年前（±120日）の記録が無い場合など、比較できないときは null。
String? _yearGrowthSummary(ChildProfile child) {
  String? heightPart;
  String? weightPart;

  final records = [...child.growthRecords]
    ..sort((a, b) => a.date.compareTo(b.date));

  ({GrowthRecord latest, GrowthRecord baseline})? findPair(
      bool Function(GrowthRecord) hasValue) {
    GrowthRecord? latest;
    for (final r in records.reversed) {
      if (hasValue(r)) {
        latest = r;
        break;
      }
    }
    if (latest == null) return null;
    final target = latest.date.subtract(const Duration(days: 365));
    GrowthRecord? baseline;
    int bestGap = 120; // 目標日から±120日以内の記録のみ採用
    for (final r in records) {
      if (!hasValue(r)) continue;
      final gap = (r.date.difference(target).inDays).abs();
      if (gap <= bestGap) {
        bestGap = gap;
        baseline = r;
      }
    }
    if (baseline == null || identical(baseline, latest)) return null;
    // 期間が短すぎる比較（半年未満）は「1年の伸び」として出さない
    if (latest.date.difference(baseline.date).inDays < 180) return null;
    return (latest: latest, baseline: baseline);
  }

  final h = findPair((r) => r.heightCm != null);
  if (h != null) {
    final diff = h.latest.heightCm! - h.baseline.heightCm!;
    if (diff > 0) heightPart = '身長 +${diff.toStringAsFixed(1)}cm';
  }
  final w = findPair((r) => r.weightKg != null);
  if (w != null) {
    final diff = w.latest.weightKg! - w.baseline.weightKg!;
    if (diff > 0) weightPart = '体重 +${formatWeightKg(diff)}kg';
  }

  if (heightPart == null && weightPart == null) return null;
  final parts = [heightPart, weightPart].whereType<String>().join('・');
  return 'この1年で $parts\n大きくなりました！';
}

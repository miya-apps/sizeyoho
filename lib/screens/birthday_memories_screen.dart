import 'dart:typed_data';

import 'package:flutter/material.dart';

import '../models/birthday_memory.dart';
import '../models/child_profile.dart';
import '../models/growth_record.dart';
import '../widgets/birthday_memory_edit_dialog.dart';
import '../widgets/birthday_photo.dart';

/// お誕生日の思い出アルバム。
/// 誕生月のお祝いダイアログで残した写真を、お子様ごと・年齢ごとに見返せる。
/// 1歳〜現在の年齢まではこの画面から直接写真を追加・差し替えできるので、
/// お祝いを閉じたあと（「今後表示しない」にした場合も含めて）でも入力できる。
class BirthdayMemoriesScreen extends StatefulWidget {
  const BirthdayMemoriesScreen({
    super.key,
    required this.children,
    required this.onUpdateChild,
  });

  final List<ChildProfile> children;
  final void Function(int index, ChildProfile updated) onUpdateChild;

  @override
  State<BirthdayMemoriesScreen> createState() => _BirthdayMemoriesScreenState();
}

class _BirthdayMemoriesScreenState extends State<BirthdayMemoriesScreen> {
  /// この画面で編集した内容を即座に反映するためのローカルコピー。
  late List<ChildProfile> _children;

  @override
  void initState() {
    super.initState();
    _children = [...widget.children];
  }

  Future<void> _editMemory(int childIndex, int age) async {
    await showBirthdayMemoryEditDialog(
      context: context,
      child: _children[childIndex],
      age: age,
      onUpdate: (updated) {
        setState(() => _children[childIndex] = updated);
        widget.onUpdateChild(childIndex, updated);
      },
    );
  }

  /// お子様1人分のアコーディオン（設定から開く複数人表示用）。
  Widget _childAccordion(int index) {
    final child = _children[index];
    return Padding(
      padding: const EdgeInsets.only(top: 10),
      child: Material(
        color: Colors.white,
        borderRadius: BorderRadius.circular(14),
        clipBehavior: Clip.antiAlias,
        child: ExpansionTile(
          // 初期はすべて閉じておく（1人だけの場合はアコーディオン自体を使わない）。
          initiallyExpanded: false,
          shape: const Border(),
          collapsedShape: const Border(),
          tilePadding: const EdgeInsets.symmetric(horizontal: 16),
          childrenPadding: const EdgeInsets.fromLTRB(16, 0, 16, 16),
          title: Text(
            child.displayName,
            style: const TextStyle(
              fontSize: 14,
              fontWeight: FontWeight.w700,
              color: Color(0xFF333333),
            ),
          ),
          subtitle: Text(
            '思い出 ${child.birthdayMemories.length}件',
            style: TextStyle(fontSize: 11.5, color: Colors.grey[700]),
          ),
          children: [
            _ChildMemoriesSection(
              child: child,
              onEdit: (age) => _editMemory(index, age),
              showName: false,
            ),
          ],
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    const bg = Color(0xFFF6F6F4);
    const fg = Color(0xFF333333);

    return Scaffold(
      backgroundColor: bg,
      appBar: AppBar(
        backgroundColor: bg,
        surfaceTintColor: Colors.transparent,
        foregroundColor: fg,
        title: const Text(
          'お誕生日の思い出',
          style: TextStyle(fontSize: 17, fontWeight: FontWeight.w700),
        ),
        centerTitle: true,
      ),
      body: SafeArea(
        child: Center(
          child: ConstrainedBox(
            constraints: const BoxConstraints(maxWidth: 600),
            child: ListView(
              padding: const EdgeInsets.fromLTRB(16, 8, 16, 24),
              children: [
                // 1人だけ（履歴から開いた場合）はそのまま、
                // 複数人（設定から開いた場合）はお子様ごとのアコーディオンで表示。
                if (_children.length == 1)
                  _ChildMemoriesSection(
                    child: _children[0],
                    onEdit: (age) => _editMemory(0, age),
                  )
                else
                  for (var i = 0; i < _children.length; i++) _childAccordion(i),
                const SizedBox(height: 12),
                Text(
                  '誕生月に表示されるお祝いからも思い出を残せます。\n'
                  'ここからは過去のお誕生日の分も追加・編集できます。',
                  textAlign: TextAlign.center,
                  style: TextStyle(
                    fontSize: 12,
                    height: 1.6,
                    color: Colors.grey[700],
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

/// 1人分の思い出（名前見出し＋年齢ごとの写真カード）。
/// 1歳から現在の年齢までのカードを常に並べ、記録が無い年は追加ボタンにする。
class _ChildMemoriesSection extends StatelessWidget {
  const _ChildMemoriesSection({
    required this.child,
    required this.onEdit,
    this.showName = true,
  });

  final ChildProfile child;
  final void Function(int age) onEdit;

  /// アコーディオン内ではヘッダーに名前が出るため、内側の名前は隠す。
  final bool showName;

  @override
  Widget build(BuildContext context) {
    // 1歳〜現在の年齢に加え、記録済みの年齢（未来分の整合も含む）を並べる。
    final ages = <int>{
      for (var a = 1; a <= child.age; a++) a,
      for (final m in child.birthdayMemories) m.age,
    }.toList()
      ..sort();

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        if (showName)
          Padding(
            padding: const EdgeInsets.fromLTRB(4, 12, 4, 8),
            child: Text(
              child.displayName,
              style: const TextStyle(
                fontSize: 14,
                fontWeight: FontWeight.w700,
                color: Color(0xFF333333),
              ),
            ),
          ),
        if (ages.isEmpty)
          Padding(
            padding: const EdgeInsets.fromLTRB(4, 0, 4, 8),
            child: Text(
              'はじめてのお誕生日を迎えたら、ここに毎年1枚ずつ写真を残せます。',
              style: TextStyle(fontSize: 12.5, color: Colors.grey[700]),
            ),
          )
        else
          // 写真部分を編集画面と同じ正方形にそろえるため、
          // セルの縦横比を「正方形＋下部テキスト」で実際の幅から計算する。
          LayoutBuilder(
            builder: (context, constraints) {
              const spacing = 12.0;
              const footerHeight = 56.0;
              final cellWidth = (constraints.maxWidth - spacing) / 2;
              return GridView.count(
                crossAxisCount: 2,
                shrinkWrap: true,
                physics: const NeverScrollableScrollPhysics(),
                mainAxisSpacing: spacing,
                crossAxisSpacing: spacing,
                childAspectRatio: cellWidth / (cellWidth + footerHeight),
                children: [
                  for (final age in ages)
                    _MemoryCard(
                      age: age,
                      memory: _memoryOf(age),
                      onEdit: () => onEdit(age),
                    ),
                ],
              );
            },
          ),
      ],
    );
  }

  BirthdayMemory? _memoryOf(int age) {
    for (final m in child.birthdayMemories) {
      if (m.age == age) return m;
    }
    return null;
  }
}

class _MemoryCard extends StatelessWidget {
  const _MemoryCard({
    required this.age,
    required this.memory,
    required this.onEdit,
  });

  final int age;
  final BirthdayMemory? memory;
  final VoidCallback onEdit;

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    final photo = memory?.photoBytes;
    final m = memory;
    final sizeParts = <String>[
      if (m?.heightCm != null) '${m!.heightCm!.toStringAsFixed(1)}cm',
      if (m?.weightKg != null) '${formatWeightKg(m!.weightKg!)}kg',
    ];

    return Card(
      margin: EdgeInsets.zero,
      color: Colors.white,
      elevation: 0.5,
      clipBehavior: Clip.antiAlias,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          // 写真エリアはセル計算上ちょうど正方形になり、
          // 編集画面で調整した切り取り位置をそのまま反映する。
          Expanded(
            child: photo != null
                ? Stack(
                    fit: StackFit.expand,
                    children: [
                      InkWell(
                        onTap: () => _showFullPhoto(context, photo),
                        child: BirthdayPhoto(
                          bytes: photo,
                          alignX: m?.photoAlignX ?? 0,
                          alignY: m?.photoAlignY ?? 0,
                          scale: m?.photoScale ?? 1.0,
                          borderRadius: 0,
                        ),
                      ),
                      // 編集用の小さなボタン（右上）。
                      Positioned(
                        top: 6,
                        right: 6,
                        child: Material(
                          color: Colors.black.withValues(alpha: 0.45),
                          shape: const CircleBorder(),
                          child: InkWell(
                            customBorder: const CircleBorder(),
                            onTap: onEdit,
                            child: const Padding(
                              padding: EdgeInsets.all(6),
                              child: Icon(
                                Icons.edit_outlined,
                                size: 15,
                                color: Colors.white,
                              ),
                            ),
                          ),
                        ),
                      ),
                    ],
                  )
                : InkWell(
                    onTap: onEdit,
                    child: Container(
                      color: scheme.primary.withValues(alpha: 0.05),
                      alignment: Alignment.center,
                      child: Column(
                        mainAxisAlignment: MainAxisAlignment.center,
                        children: [
                          Icon(
                            m == null
                                ? Icons.add_a_photo_outlined
                                : Icons.edit_outlined,
                            size: 26,
                            color: scheme.primary,
                          ),
                          const SizedBox(height: 6),
                          Text(
                            m == null ? '思い出を追加' : '写真を追加',
                            style: TextStyle(
                              fontSize: 12,
                              fontWeight: FontWeight.w600,
                              color: scheme.primary,
                            ),
                          ),
                        ],
                      ),
                    ),
                  ),
          ),
          // 高さ固定の下部テキスト（セルの縦横比計算と一致させる）。
          SizedBox(
            height: 56,
            child: Padding(
              padding: const EdgeInsets.fromLTRB(10, 7, 10, 6),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    children: [
                      Text(
                        '$age歳',
                        style: const TextStyle(
                          fontSize: 13,
                          fontWeight: FontWeight.w700,
                          color: Color(0xFF333333),
                        ),
                      ),
                      const SizedBox(width: 6),
                      if (sizeParts.isNotEmpty)
                        Expanded(
                          child: Text(
                            sizeParts.join('・'),
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                            textAlign: TextAlign.right,
                            style: TextStyle(
                              fontSize: 11.5,
                              fontWeight: FontWeight.w600,
                              color: Colors.grey[700],
                            ),
                          ),
                        ),
                    ],
                  ),
                  if (m?.note != null && m!.note!.isNotEmpty) ...[
                    const SizedBox(height: 2),
                    Text(
                      m.note!,
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: TextStyle(fontSize: 11, color: Colors.grey[700]),
                    ),
                  ],
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }

  /// 写真を拡大表示する（ピンチで拡大縮小できる）。
  void _showFullPhoto(BuildContext context, Uint8List photo) {
    showDialog<void>(
      context: context,
      builder: (dialogContext) => Dialog(
        backgroundColor: Colors.transparent,
        insetPadding: const EdgeInsets.all(16),
        child: GestureDetector(
          onTap: () => Navigator.of(dialogContext).pop(),
          child: InteractiveViewer(
            child: ClipRRect(
              borderRadius: BorderRadius.circular(16),
              child: Image.memory(photo, fit: BoxFit.contain),
            ),
          ),
        ),
      ),
    );
  }
}

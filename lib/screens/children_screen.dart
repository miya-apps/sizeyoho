import 'dart:typed_data';

import 'package:flutter/foundation.dart' show kIsWeb;

import 'package:flutter/cupertino.dart'
    show
        CupertinoActionSheet,
        CupertinoActionSheetAction,
        showCupertinoModalPopup;
import 'package:flutter/material.dart';
import 'package:image_picker/image_picker.dart';

import '../app/adaptive_layout.dart';
import '../models/child_profile.dart';
import '../models/gender.dart';
import '../models/growth_record.dart';
import '../widgets/child_profile_tile.dart';

String _formatBirthDate(DateTime d) => '${d.year}年${d.month}月${d.day}日';

/// 出生記録（プロフィールの出生時身長・体重から自動生成する記録）の ID。
/// この ID で紐付けることで、プロフィール編集時に出生記録を同期更新できる。
String _birthRecordIdFor(String childId) => 'birth_$childId';

GrowthRecord? _findBirthRecord(ChildProfile? child) {
  if (child == null) return null;
  final id = _birthRecordIdFor(child.id);
  for (final r in child.growthRecords) {
    if (r.id == id) return r;
  }
  return null;
}

/// 出生時身長・体重の入力値を出生記録として記録リストへ反映する。
/// 両方未入力なら出生記録を取り除いたリストを返す（手入力の他記録は不変）。
List<GrowthRecord> _syncBirthRecord(
  List<GrowthRecord> records,
  String childId,
  DateTime birthDate, {
  double? heightCm,
  double? weightKg,
}) {
  final id = _birthRecordIdFor(childId);
  final rest = records.where((r) => r.id != id).toList();
  if (heightCm == null && weightKg == null) return rest;
  return [
    GrowthRecord(id: id, date: birthDate, heightCm: heightCm, weightKg: weightKg),
    ...rest,
  ];
}

bool _isThemeColorUsedByOther(
  List<ChildProfile> children,
  Color color,
  ChildProfile? editing,
) {
  for (final c in children) {
    if (editing != null && c.id == editing.id) continue;
    if (c.themeColor == color) return true;
  }
  return false;
}

Color _defaultThemeColorFor(
  List<ChildProfile> children,
  ChildProfile? editing,
) {
  for (final color in ChildProfileTile.kThemeColors) {
    if (!_isThemeColorUsedByOther(children, color, editing)) return color;
  }
  return ChildProfileTile.kThemeColors.first;
}

/// お子様プロフィールの追加・編集ボトムシートを表示する。
void showChildProfileModal(
  BuildContext context, {
  required List<ChildProfile> children,
  void Function(int index, ChildProfile updated)? onUpdateChild,
  ValueChanged<ChildProfile>? onAddChild,
  ChildProfile? editing,
  int? editingIndex,
}) {
  _showChildProfileModalImpl(
    context,
    children: children,
    onUpdateChild: onUpdateChild,
    onAddChild: onAddChild,
    editing: editing,
    editingIndex: editingIndex,
  );
}

void _showChildProfileModalImpl(
  BuildContext context, {
  required List<ChildProfile> children,
  void Function(int index, ChildProfile updated)? onUpdateChild,
  ValueChanged<ChildProfile>? onAddChild,
  ChildProfile? editing,
  int? editingIndex,
}) {
  final isEditing = editing != null;
  final nameCtrl = TextEditingController(text: editing?.name ?? '');
  // 両親の身長（任意）。整数値なら小数点なしで表示する。
  String formatParentHeight(double? v) => v == null
      ? ''
      : (v == v.roundToDouble() ? v.toStringAsFixed(0) : v.toString());
  final fatherHeightCtrl = TextEditingController(
    text: formatParentHeight(editing?.fatherHeightCm),
  );
  final motherHeightCtrl = TextEditingController(
    text: formatParentHeight(editing?.motherHeightCm),
  );
  // 出生時の身長・体重（任意）。既存の出生記録があればその値を初期表示する。
  // 体重は母子手帳に合わせて g 単位で入力する（内部保存は kg）。
  final birthRecord = _findBirthRecord(editing);
  String formatMeasure(double? v) => v == null
      ? ''
      : (v == v.roundToDouble() ? v.toStringAsFixed(0) : v.toString());
  final birthHeightCtrl = TextEditingController(
    text: formatMeasure(birthRecord?.heightCm),
  );
  final birthWeightCtrl = TextEditingController(
    text: birthRecord?.weightKg == null
        ? ''
        : (birthRecord!.weightKg! * 1000).round().toString(),
  );
  // 保存時の入力エラー（シート内に表示する。スナックバーはシートの裏に
  // 隠れて見えないため使わない）。
  String? errorText;
  var birthDate =
      editing?.birthDate ??
      DateTime(
        DateTime.now().year - 3,
        DateTime.now().month,
        DateTime.now().day,
      );
  // 未選択（null）を許容し、保存時に必須チェックする。
  Gender? gender = editing?.gender;
  var themeColor =
      editing?.themeColor ?? _defaultThemeColorFor(children, editing);
  var iconIndex = editing?.iconIndex ?? 0;
  Uint8List? photoBytes = editing?.photoBytes;
  // 修正月齢（Corrected Age）関連の状態
  var useCorrectedAge = editing?.useCorrectedAge ?? false;
  DateTime? expectedBirthDate = editing?.expectedBirthDate;
  showModalBottomSheet<void>(
    context: context,
    isScrollControlled: true,
    showDragHandle: true,
    backgroundColor: Theme.of(context).colorScheme.surfaceContainerLowest,
    shape: const RoundedRectangleBorder(
      borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
    ),
    builder: (sheetCtx) => StatefulBuilder(
      builder: (ctx, setS) {
        final scheme = Theme.of(ctx).colorScheme;
        // ── カメラ / ギャラリーから写真 ────────────────────────────────
        Future<void> pickImageFrom(ImageSource source) async {
          final picker = ImagePicker();
          final XFile? xf = await picker.pickImage(
            source: source,
            maxWidth: 512,
            maxHeight: 512,
            imageQuality: 85,
          );
          if (xf != null) {
            final bytes = await xf.readAsBytes();
            setS(() => photoBytes = bytes);
          }
        }

        void showPhotoSourceActionSheet(BuildContext avatarSheetCtx) {
          final isIOS = Theme.of(ctx).platform == TargetPlatform.iOS;

          Future<void> pickAndApply(ImageSource source) async {
            Navigator.pop(avatarSheetCtx);
            await pickImageFrom(source);
          }

          if (isIOS) {
            showCupertinoModalPopup<void>(
              context: avatarSheetCtx,
              builder: (popupCtx) => CupertinoActionSheet(
                actions: [
                  CupertinoActionSheetAction(
                    onPressed: () {
                      Navigator.pop(popupCtx);
                      pickAndApply(ImageSource.camera);
                    },
                    child: const Text('写真を撮影する'),
                  ),
                  CupertinoActionSheetAction(
                    onPressed: () {
                      Navigator.pop(popupCtx);
                      pickAndApply(ImageSource.gallery);
                    },
                    child: const Text('アルバムから選ぶ'),
                  ),
                ],
                cancelButton: CupertinoActionSheetAction(
                  onPressed: () => Navigator.pop(popupCtx),
                  child: const Text('キャンセル'),
                ),
              ),
            );
          } else {
            showModalBottomSheet<void>(
              context: avatarSheetCtx,
              backgroundColor: scheme.surfaceContainerLowest,
              shape: const RoundedRectangleBorder(
                borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
              ),
              builder: (sourceCtx) => SafeArea(
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    ListTile(
                      leading: Icon(Icons.camera_alt, color: scheme.onSurface),
                      title: const Text('写真を撮影する'),
                      onTap: () {
                        Navigator.pop(sourceCtx);
                        pickAndApply(ImageSource.camera);
                      },
                    ),
                    ListTile(
                      leading: Icon(
                        Icons.photo_library,
                        color: scheme.onSurface,
                      ),
                      title: const Text('アルバムから選ぶ'),
                      onTap: () {
                        Navigator.pop(sourceCtx);
                        pickAndApply(ImageSource.gallery);
                      },
                    ),
                    ListTile(
                      leading: Icon(
                        Icons.close,
                        color: scheme.onSurfaceVariant,
                      ),
                      title: const Text('キャンセル'),
                      onTap: () => Navigator.pop(sourceCtx),
                    ),
                  ],
                ),
              ),
            );
          }
        }

        void showAvatarPickerSheet() {
          showModalBottomSheet<void>(
            context: ctx,
            isScrollControlled: true,
            backgroundColor: scheme.surfaceContainerLowest,
            shape: const RoundedRectangleBorder(
              borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
            ),
            builder: (actionCtx) {
              final gridItemCount = 1 + kChildIconOptions.length;
              final selBg = themeColor.withValues(alpha: 0.14);
              final selFg = Color.lerp(themeColor, Colors.black, 0.35)!;
              const gridSpacing = 6.0;
              const iconSize = 28.0;
              return SafeArea(
                child: Padding(
                  padding: const EdgeInsets.fromLTRB(16, 8, 16, 12),
                  child: Column(
                    mainAxisSize: MainAxisSize.min,
                    crossAxisAlignment: CrossAxisAlignment.stretch,
                    children: [
                      Text(
                        'アイコンを選ぶ',
                        textAlign: TextAlign.center,
                        style: TextStyle(
                          fontSize: 16,
                          fontWeight: FontWeight.w700,
                          color: scheme.onSurface,
                        ),
                      ),
                      const SizedBox(height: 10),
                      LayoutBuilder(
                        builder: (context, constraints) {
                          final cellWidth =
                              (constraints.maxWidth - gridSpacing * 4) / 5;
                          final gridHeight = cellWidth * 5 + gridSpacing * 4;
                          return SizedBox(
                            height: gridHeight,
                            child: GridView.builder(
                              physics: const NeverScrollableScrollPhysics(),
                              gridDelegate:
                                  SliverGridDelegateWithFixedCrossAxisCount(
                                    crossAxisCount: 5,
                                    mainAxisSpacing: gridSpacing,
                                    crossAxisSpacing: gridSpacing,
                                    childAspectRatio: 1.0,
                                  ),
                              itemCount: gridItemCount,
                              itemBuilder: (_, index) {
                                if (index == 0) {
                                  final isPhotoSel = photoBytes != null;
                                  return GestureDetector(
                                    // Web ではブラウザ側が「写真ライブラリ／写真を
                                    // 撮る／ファイルを選択」の選択肢を出すため、
                                    // アプリ内の出所メニューを挟むと二重になる。
                                    // Web はブラウザの選択に直行し、ネイティブでは
                                    // 従来どおりアプリ内メニューを出す。
                                    onTap: kIsWeb
                                        ? () {
                                            Navigator.pop(actionCtx);
                                            pickImageFrom(ImageSource.gallery);
                                          }
                                        : () => showPhotoSourceActionSheet(
                                            actionCtx,
                                          ),
                                    child: Container(
                                      decoration: BoxDecoration(
                                        color: isPhotoSel
                                            ? selBg
                                            : scheme.surfaceContainerLow,
                                        borderRadius: BorderRadius.circular(10),
                                        border: isPhotoSel
                                            ? Border.all(
                                                color: themeColor,
                                                width: 2,
                                              )
                                            : Border.all(
                                                color: scheme.outlineVariant
                                                    .withValues(alpha: 0.4),
                                              ),
                                      ),
                                      child: Column(
                                        mainAxisAlignment:
                                            MainAxisAlignment.center,
                                        children: [
                                          Icon(
                                            Icons.camera_alt,
                                            size: 20,
                                            color: isPhotoSel
                                                ? selFg
                                                : scheme.onSurfaceVariant,
                                          ),
                                          const SizedBox(height: 2),
                                          Text(
                                            '写真を選ぶ',
                                            textAlign: TextAlign.center,
                                            maxLines: 2,
                                            style: TextStyle(
                                              fontSize: 7,
                                              fontWeight: FontWeight.w600,
                                              height: 1.1,
                                              color: isPhotoSel
                                                  ? selFg
                                                  : scheme.onSurfaceVariant,
                                            ),
                                            overflow: TextOverflow.ellipsis,
                                          ),
                                        ],
                                      ),
                                    ),
                                  );
                                }

                                final i = index - 1;
                                final icon = kChildIconOptions[i];
                                final isSel =
                                    photoBytes == null && i == iconIndex;
                                return GestureDetector(
                                  onTap: () {
                                    setS(() {
                                      iconIndex = i;
                                      photoBytes = null;
                                    });
                                    Navigator.pop(actionCtx);
                                  },
                                  child: Container(
                                    decoration: BoxDecoration(
                                      color: isSel
                                          ? selBg
                                          : scheme.surfaceContainerLow,
                                      borderRadius: BorderRadius.circular(10),
                                      border: isSel
                                          ? Border.all(
                                              color: themeColor,
                                              width: 2,
                                            )
                                          : null,
                                    ),
                                    child: Center(
                                      child: Icon(
                                        icon,
                                        size: iconSize,
                                        color: isSel
                                            ? selFg
                                            : scheme.onSurfaceVariant,
                                      ),
                                    ),
                                  ),
                                );
                              },
                            ),
                          );
                        },
                      ),
                    ],
                  ),
                ),
              );
            },
          );
        }

        // ── アバター ─────────────────────────────────────────────
        final avatarFg = Color.lerp(themeColor, Colors.black, 0.4)!;
        final Widget avatarCircle = GestureDetector(
          onTap: showAvatarPickerSheet,
          child: Stack(
            alignment: Alignment.bottomRight,
            children: [
              Container(
                width: 88,
                height: 88,
                decoration: BoxDecoration(
                  color: themeColor.withValues(alpha: 0.2),
                  shape: BoxShape.circle,
                  border: Border.all(color: themeColor, width: 2.5),
                ),
                child: ClipOval(
                  child: photoBytes != null
                      ? Image.memory(
                          photoBytes!,
                          fit: BoxFit.cover,
                          width: 88,
                          height: 88,
                        )
                      : Icon(
                          kChildIconOptions[iconIndex.clamp(
                            0,
                            kChildIconOptions.length - 1,
                          )],
                          size: 44,
                          color: avatarFg,
                        ),
                ),
              ),
              Container(
                width: 28,
                height: 28,
                decoration: BoxDecoration(
                  color: themeColor,
                  shape: BoxShape.circle,
                  border: Border.all(color: scheme.surface, width: 2),
                ),
                child: const Icon(
                  Icons.camera_alt_rounded,
                  size: 14,
                  color: Colors.white,
                ),
              ),
            ],
          ),
        );

        return Padding(
          padding: EdgeInsets.fromLTRB(
            24,
            8,
            24,
            MediaQuery.viewInsetsOf(ctx).bottom + 24,
          ),
          child: SingleChildScrollView(
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                // ─ タイトル ─
                Text(
                  isEditing ? '✏️ プロフィールを編集' : '👶 お子様を追加',
                  style: const TextStyle(
                    fontSize: 18,
                    fontWeight: FontWeight.bold,
                  ),
                ),
                const SizedBox(height: 20),
                // ─ アバター ─
                Center(
                  child: Column(
                    children: [
                      avatarCircle,
                      const SizedBox(height: 6),
                      Text(
                        photoBytes != null ? 'タップして変更' : 'タップして写真・アイコンを選ぶ',
                        style: TextStyle(
                          fontSize: 12,
                          color: Color.lerp(themeColor, Colors.black, 0.45),
                          fontWeight: FontWeight.w600,
                        ),
                      ),
                    ],
                  ),
                ),
                const SizedBox(height: 20),
                // ─ 名前 ─
                TextField(
                  controller: nameCtrl,
                  decoration: const InputDecoration(
                    labelText: '名前',
                    border: OutlineInputBorder(),
                  ),
                ),
                const SizedBox(height: 12),
                // ─ 生年月日（修正月齢のサブ設定を内包） ─
                // 複合 child だと InputDecorator の切り欠きが安定しないため、
                // 性別欄と同じ「枠付き Container ＋ 背景色マスクのラベル」方式に統一。
                Stack(
                  clipBehavior: Clip.none,
                  children: [
                    Container(
                      width: double.infinity,
                      margin: const EdgeInsets.only(top: 8),
                      padding: const EdgeInsets.fromLTRB(12, 4, 8, 8),
                      decoration: BoxDecoration(
                        border: Border.all(color: scheme.outline, width: 1),
                        borderRadius: BorderRadius.circular(4),
                      ),
                      child: Column(
                        mainAxisSize: MainAxisSize.min,
                        crossAxisAlignment: CrossAxisAlignment.stretch,
                        children: [
                          // ── 生年月日の日付選択 ──
                          InkWell(
                            borderRadius: BorderRadius.circular(4),
                            onTap: () async {
                              final picked = await showDatePicker(
                                context: ctx,
                                initialDate: birthDate,
                                firstDate: DateTime(DateTime.now().year - 18),
                                lastDate: DateTime.now(),
                                helpText: '生年月日を選択',
                                cancelText: 'キャンセル',
                                confirmText: '確定',
                              );
                              if (picked != null) {
                                setS(() => birthDate = picked);
                              }
                            },
                            child: Padding(
                              padding: const EdgeInsets.symmetric(vertical: 10),
                              child: Row(
                                children: [
                                  Expanded(
                                    child: Text(
                                      _formatBirthDate(birthDate),
                                      style: const TextStyle(fontSize: 15),
                                    ),
                                  ),
                                  Icon(
                                    Icons.calendar_month_rounded,
                                    color: scheme.onSurfaceVariant,
                                  ),
                                ],
                              ),
                            ),
                          ),
                          // ── 区切り線 ──
                          Divider(
                            height: 8,
                            thickness: 1,
                            color: scheme.outlineVariant.withValues(alpha: 0.6),
                          ),
                          // ── 修正月齢を使用する（生年月日のサブ設定として控えめに）──
                          SwitchListTile(
                            contentPadding: EdgeInsets.zero,
                            dense: true,
                            title: Text(
                              '修正月齢を使用する',
                              style: TextStyle(
                                fontSize: 14,
                                fontWeight: FontWeight.w500,
                                color: scheme.onSurface,
                              ),
                            ),
                            subtitle: Text(
                              '早産のお子様向け。出産予定日を基準に発育を評価します',
                              style: TextStyle(
                                fontSize: 11,
                                color: scheme.onSurfaceVariant,
                              ),
                            ),
                            value: useCorrectedAge,
                            activeThumbColor: themeColor,
                            onChanged: (v) => setS(() {
                              useCorrectedAge = v;
                              // ON にした際、未設定なら生年月日を初期値にして入力を促す
                              if (v && expectedBirthDate == null) {
                                expectedBirthDate = birthDate;
                              }
                            }),
                          ),
                          // ── 出産予定日（ON のときだけ同じ枠内でスッと展開）──
                          AnimatedSize(
                            duration: const Duration(milliseconds: 250),
                            curve: Curves.easeInOut,
                            alignment: Alignment.topCenter,
                            child: useCorrectedAge
                                ? Padding(
                                    padding: const EdgeInsets.only(
                                      top: 4,
                                      bottom: 4,
                                    ),
                                    child: InkWell(
                                      borderRadius: BorderRadius.circular(4),
                                      onTap: () async {
                                        final picked = await showDatePicker(
                                          context: ctx,
                                          initialDate:
                                              expectedBirthDate ?? birthDate,
                                          firstDate: DateTime(
                                            DateTime.now().year - 18,
                                          ),
                                          lastDate: DateTime(
                                            DateTime.now().year + 2,
                                          ),
                                          helpText: '出産予定日を選択',
                                          cancelText: 'キャンセル',
                                          confirmText: '確定',
                                        );
                                        if (picked != null) {
                                          setS(
                                            () => expectedBirthDate = picked,
                                          );
                                        }
                                      },
                                      child: InputDecorator(
                                        decoration: const InputDecoration(
                                          labelText: '出産予定日',
                                          border: OutlineInputBorder(),
                                          suffixIcon: Icon(
                                            Icons.event_available_rounded,
                                          ),
                                          isDense: true,
                                        ),
                                        child: Text(
                                          expectedBirthDate != null
                                              ? _formatBirthDate(
                                                  expectedBirthDate!,
                                                )
                                              : '日付を選択してください',
                                          style: TextStyle(
                                            fontSize: 15,
                                            color: expectedBirthDate != null
                                                ? scheme.onSurface
                                                : scheme.onSurfaceVariant,
                                          ),
                                        ),
                                      ),
                                    ),
                                  )
                                : const SizedBox(width: double.infinity),
                          ),
                        ],
                      ),
                    ),
                    // ラベル：シート背景色で塗り、上辺の枠線をマスク。
                    Positioned(
                      left: 12,
                      top: 0,
                      child: Container(
                        color: scheme.surfaceContainerLowest,
                        padding: const EdgeInsets.symmetric(horizontal: 4),
                        child: Text(
                          '生年月日',
                          style: TextStyle(
                            fontSize: 12,
                            color: scheme.onSurfaceVariant,
                          ),
                        ),
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 12),
                // ─ 出生時の身長・体重（任意） ─
                // 入力すると生年月日の日付で「最初の成長記録」を自動登録する。
                Stack(
                  clipBehavior: Clip.none,
                  children: [
                    Container(
                      width: double.infinity,
                      margin: const EdgeInsets.only(top: 8),
                      padding: const EdgeInsets.fromLTRB(12, 14, 12, 12),
                      decoration: BoxDecoration(
                        border: Border.all(color: scheme.outline, width: 1),
                        borderRadius: BorderRadius.circular(4),
                      ),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.stretch,
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          Row(
                            children: [
                              Expanded(
                                child: TextField(
                                  controller: birthHeightCtrl,
                                  keyboardType:
                                      const TextInputType.numberWithOptions(
                                        decimal: true,
                                      ),
                                  decoration: const InputDecoration(
                                    labelText: '出生時の身長',
                                    suffixText: 'cm',
                                    border: OutlineInputBorder(),
                                    isDense: true,
                                  ),
                                ),
                              ),
                              const SizedBox(width: 12),
                              Expanded(
                                child: TextField(
                                  controller: birthWeightCtrl,
                                  keyboardType: TextInputType.number,
                                  decoration: const InputDecoration(
                                    labelText: '出生時の体重',
                                    suffixText: 'g',
                                    hintText: '例: 3100',
                                    border: OutlineInputBorder(),
                                    isDense: true,
                                  ),
                                ),
                              ),
                            ],
                          ),
                          const SizedBox(height: 8),
                          Text(
                            '※入力すると、生まれた日の記録として最初の成長記録に自動で登録されます',
                            style: TextStyle(
                              fontSize: 11,
                              height: 1.3,
                              color: scheme.onSurfaceVariant.withValues(
                                alpha: 0.7,
                              ),
                            ),
                          ),
                        ],
                      ),
                    ),
                    // ラベル：シート背景色で塗り、上辺の枠線をマスク。
                    Positioned(
                      left: 12,
                      top: 0,
                      child: Container(
                        color: scheme.surfaceContainerLowest,
                        padding: const EdgeInsets.symmetric(horizontal: 4),
                        child: Text(
                          '出生時の身長・体重（任意）',
                          style: TextStyle(
                            fontSize: 12,
                            color: scheme.onSurfaceVariant,
                          ),
                        ),
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 12),
                // ─ テーマカラー ─
                InputDecorator(
                  decoration: const InputDecoration(
                    labelText: 'テーマカラー',
                    border: OutlineInputBorder(),
                    contentPadding: EdgeInsets.symmetric(
                      horizontal: 14,
                      vertical: 14,
                    ),
                  ),
                  child: Row(
                    children: ChildProfileTile.kThemeColors.map((color) {
                      final isSel = color == themeColor;
                      final isUsed = _isThemeColorUsedByOther(
                        children,
                        color,
                        editing,
                      );
                      return GestureDetector(
                        onTap: isUsed
                            ? null
                            : () => setS(() => themeColor = color),
                        child: Opacity(
                          opacity: isUsed ? 0.5 : 1.0,
                          child: AnimatedContainer(
                            duration: const Duration(milliseconds: 150),
                            margin: const EdgeInsets.only(right: 10),
                            width: 34,
                            height: 34,
                            decoration: BoxDecoration(
                              color: color,
                              shape: BoxShape.circle,
                              border: isSel
                                  ? Border.all(color: Colors.white, width: 3)
                                  : Border.all(
                                      color: Colors.transparent,
                                      width: 3,
                                    ),
                              boxShadow: isSel && !isUsed
                                  ? [
                                      BoxShadow(
                                        color: color.withValues(alpha: 0.6),
                                        blurRadius: 8,
                                        spreadRadius: 1,
                                      ),
                                    ]
                                  : null,
                            ),
                            child: Stack(
                              fit: StackFit.expand,
                              alignment: Alignment.center,
                              clipBehavior: Clip.hardEdge,
                              children: [
                                if (isSel && !isUsed)
                                  const Icon(
                                    Icons.check_rounded,
                                    size: 18,
                                    color: Colors.white,
                                  ),
                                if (isUsed)
                                  Positioned.fill(
                                    child: DecoratedBox(
                                      decoration: BoxDecoration(
                                        shape: BoxShape.circle,
                                        color: Colors.black.withValues(
                                          alpha: 0.42,
                                        ),
                                      ),
                                      child: Center(
                                        child: FittedBox(
                                          fit: BoxFit.scaleDown,
                                          child: Padding(
                                            padding: const EdgeInsets.symmetric(
                                              horizontal: 3,
                                            ),
                                            child: Text(
                                              '使用中',
                                              maxLines: 1,
                                              style: TextStyle(
                                                fontSize: 10,
                                                fontWeight: FontWeight.bold,
                                                color: Colors.white,
                                                height: 1.0,
                                                shadows: const [
                                                  Shadow(
                                                    color: Colors.black,
                                                    blurRadius: 2,
                                                  ),
                                                ],
                                              ),
                                            ),
                                          ),
                                        ),
                                      ),
                                    ),
                                  ),
                              ],
                            ),
                          ),
                        ),
                      );
                    }).toList(),
                  ),
                ),
                const SizedBox(height: 12),
                // ─ 性別 ─
                // InputDecorator のフローティングラベルは複合 child（Column）だと
                // 切り欠きが安定せずラベルに枠線が重なる。確実に線を断つため、
                // 枠付き Container ＋ ラベルを背景色マスクで重ねるカスタム実装にする。
                Stack(
                  clipBehavior: Clip.none,
                  children: [
                    Container(
                      // 上辺をラベルが跨ぐぶんの余白を確保
                      width: double.infinity,
                      margin: const EdgeInsets.only(top: 8),
                      padding: const EdgeInsets.fromLTRB(12, 14, 12, 12),
                      decoration: BoxDecoration(
                        border: Border.all(color: scheme.outline, width: 1),
                        borderRadius: BorderRadius.circular(4),
                      ),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.stretch,
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          // 各セグメントを枠内幅の 50% ずつに均等配分して横幅 100% に広げる。
                          LayoutBuilder(
                            builder: (context, constraints) {
                              // 外周＋仕切りの枠線ぶんを差し引いて 2 等分。
                              final segWidth = (constraints.maxWidth - 3) / 2;
                              return SegmentedButton<Gender>(
                                showSelectedIcon: false,
                                emptySelectionAllowed: true,
                                style: SegmentedButton.styleFrom(
                                  padding: EdgeInsets.zero,
                                  visualDensity: VisualDensity.compact,
                                ),
                                segments: Gender.values
                                    .map(
                                      (g) => ButtonSegment<Gender>(
                                        value: g,
                                        label: SizedBox(
                                          width: segWidth,
                                          child: Center(
                                            child: Text(
                                              g.label,
                                              style: const TextStyle(
                                                fontSize: 13,
                                              ),
                                            ),
                                          ),
                                        ),
                                      ),
                                    )
                                    .toList(),
                                selected: {if (gender != null) gender!},
                                onSelectionChanged: (s) => setS(
                                  () => gender = s.isEmpty ? null : s.first,
                                ),
                              );
                            },
                          ),
                          const SizedBox(height: 8),
                          // 控えめな補足説明（成長曲線計算のための性別の必要性）
                          Text(
                            '※正確な成長曲線の計算のため、出生時の身体的性別をご選択ください',
                            style: TextStyle(
                              fontSize: 11,
                              height: 1.3,
                              color: scheme.onSurfaceVariant.withValues(
                                alpha: 0.7,
                              ),
                            ),
                          ),
                        ],
                      ),
                    ),
                    // ラベル：シート背景色で塗り、左右に余白を取って上辺の線をマスク。
                    Positioned(
                      left: 12,
                      top: 0,
                      child: Container(
                        color: scheme.surfaceContainerLowest,
                        padding: const EdgeInsets.symmetric(horizontal: 4),
                        child: Text(
                          '性別',
                          style: TextStyle(
                            fontSize: 12,
                            color: scheme.onSurfaceVariant,
                          ),
                        ),
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 12),
                // ─ 両親の身長（任意） ─
                // PDF出力（医師向け）に記載する目標身長（MPH）の計算に使う。
                Stack(
                  clipBehavior: Clip.none,
                  children: [
                    Container(
                      width: double.infinity,
                      margin: const EdgeInsets.only(top: 8),
                      padding: const EdgeInsets.fromLTRB(12, 14, 12, 12),
                      decoration: BoxDecoration(
                        border: Border.all(color: scheme.outline, width: 1),
                        borderRadius: BorderRadius.circular(4),
                      ),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.stretch,
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          Row(
                            children: [
                              Expanded(
                                child: TextField(
                                  controller: fatherHeightCtrl,
                                  keyboardType:
                                      const TextInputType.numberWithOptions(
                                        decimal: true,
                                      ),
                                  decoration: const InputDecoration(
                                    labelText: '父の身長',
                                    suffixText: 'cm',
                                    border: OutlineInputBorder(),
                                    isDense: true,
                                  ),
                                ),
                              ),
                              const SizedBox(width: 12),
                              Expanded(
                                child: TextField(
                                  controller: motherHeightCtrl,
                                  keyboardType:
                                      const TextInputType.numberWithOptions(
                                        decimal: true,
                                      ),
                                  decoration: const InputDecoration(
                                    labelText: '母の身長',
                                    suffixText: 'cm',
                                    border: OutlineInputBorder(),
                                    isDense: true,
                                  ),
                                ),
                              ),
                            ],
                          ),
                          const SizedBox(height: 8),
                          Text(
                            '※PDF出力時、医師の参考になる目標身長（両親の身長から計算）の記載に使用します',
                            style: TextStyle(
                              fontSize: 11,
                              height: 1.3,
                              color: scheme.onSurfaceVariant.withValues(
                                alpha: 0.7,
                              ),
                            ),
                          ),
                        ],
                      ),
                    ),
                    // ラベル：シート背景色で塗り、上辺の枠線をマスク。
                    Positioned(
                      left: 12,
                      top: 0,
                      child: Container(
                        color: scheme.surfaceContainerLowest,
                        padding: const EdgeInsets.symmetric(horizontal: 4),
                        child: Text(
                          '両親の身長（任意）',
                          style: TextStyle(
                            fontSize: 12,
                            color: scheme.onSurfaceVariant,
                          ),
                        ),
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 24),
                // ─ 入力エラー（保存ボタンの直上に表示） ─
                if (errorText != null) ...[
                  Container(
                    padding: const EdgeInsets.symmetric(
                      horizontal: 12,
                      vertical: 10,
                    ),
                    decoration: BoxDecoration(
                      color: scheme.errorContainer,
                      borderRadius: BorderRadius.circular(10),
                    ),
                    child: Row(
                      children: [
                        Icon(
                          Icons.error_outline_rounded,
                          size: 18,
                          color: scheme.onErrorContainer,
                        ),
                        const SizedBox(width: 8),
                        Expanded(
                          child: Text(
                            errorText!,
                            style: TextStyle(
                              fontSize: 13,
                              height: 1.3,
                              fontWeight: FontWeight.w600,
                              color: scheme.onErrorContainer,
                            ),
                          ),
                        ),
                      ],
                    ),
                  ),
                  const SizedBox(height: 12),
                ],
                // ─ キャンセル / 保存 ─
                Row(
                  children: [
                    Expanded(
                      child: OutlinedButton(
                        onPressed: () => Navigator.pop(sheetCtx),
                        style: OutlinedButton.styleFrom(
                          padding: const EdgeInsets.symmetric(vertical: 14),
                          shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(14),
                          ),
                        ),
                        child: const Text(
                          'キャンセル',
                          style: TextStyle(fontWeight: FontWeight.w600),
                        ),
                      ),
                    ),
                    const SizedBox(width: 12),
                    Expanded(
                      flex: 2,
                      child: FilledButton.icon(
                        onPressed: () {
                          // 入力エラーはスナックバーではなくシート内バナーに出す
                          // （スナックバーはモーダルの裏に隠れて見えないため）。
                          void showError(String message) {
                            setS(() => errorText = message);
                          }

                          final name = nameCtrl.text.trim();
                          if (name.isEmpty) {
                            showError('名前を入力してください');
                            return;
                          }
                          // 性別は成長曲線計算に必須。未選択なら保存をブロック。
                          if (gender == null) {
                            showError('性別を選択してください');
                            return;
                          }
                          // 修正月齢 ON の場合は出産予定日が必須
                          if (useCorrectedAge && expectedBirthDate == null) {
                            showError('出産予定日を選択してください');
                            return;
                          }
                          // 両親の身長（任意）。入力があれば数値・現実的な範囲かを確認。
                          // (valid, value) を返し、valid=false なら保存をブロック。
                          (bool, double?) parseParentHeight(String raw) {
                            final text = raw.trim();
                            if (text.isEmpty) return (true, null);
                            final v = double.tryParse(text);
                            if (v == null || v < 100 || v > 250) {
                              return (false, null);
                            }
                            return (true, v);
                          }

                          final (fatherOk, fatherHeight) = parseParentHeight(
                            fatherHeightCtrl.text,
                          );
                          final (motherOk, motherHeight) = parseParentHeight(
                            motherHeightCtrl.text,
                          );
                          if (!fatherOk || !motherOk) {
                            showError('両親の身長は 100〜250cm の数値で入力してください');
                            return;
                          }
                          // 出生時の身長・体重（任意）。入力があれば現実的な範囲かを確認。
                          (bool, double?) parseBirthMeasure(
                            String raw,
                            double min,
                            double max,
                          ) {
                            final text = raw.trim();
                            if (text.isEmpty) return (true, null);
                            final v = double.tryParse(text);
                            if (v == null || v < min || v > max) {
                              return (false, null);
                            }
                            return (true, v);
                          }

                          final (birthHeightOk, birthHeight) =
                              parseBirthMeasure(birthHeightCtrl.text, 20, 70);
                          // 体重は g で入力（200〜8000g）→ kg に換算して保存。
                          final (birthWeightOk, birthWeightG) =
                              parseBirthMeasure(birthWeightCtrl.text, 200, 8000);
                          if (!birthHeightOk || !birthWeightOk) {
                            showError(
                              !birthHeightOk
                                  ? '出生時の身長は 20〜70cm の数値で入力してください'
                                  : '出生時の体重は 200〜8000g の数値で入力してください',
                            );
                            return;
                          }
                          final birthWeight =
                              birthWeightG == null ? null : birthWeightG / 1000;
                          // OFF のときは予定日を保存しない（クリア）
                          final savedExpected = useCorrectedAge
                              ? expectedBirthDate
                              : null;
                          if (isEditing) {
                            onUpdateChild!(
                              editingIndex!,
                              editing.copyWith(
                                name: name,
                                birthDate: birthDate,
                                gender: gender!,
                                iconIndex: iconIndex,
                                photoBytes: photoBytes,
                                themeColor: themeColor,
                                useCorrectedAge: useCorrectedAge,
                                expectedBirthDate: savedExpected,
                                fatherHeightCm: fatherHeight,
                                motherHeightCm: motherHeight,
                                // 出生時身長・体重の変更（生年月日の変更含む）を
                                // 出生記録へ反映。両方クリアなら記録も削除する。
                                growthRecords: _syncBirthRecord(
                                  editing.growthRecords,
                                  editing.id,
                                  birthDate,
                                  heightCm: birthHeight,
                                  weightKg: birthWeight,
                                ),
                              ),
                            );
                            Navigator.pop(sheetCtx);
                            ScaffoldMessenger.of(context).showSnackBar(
                              const SnackBar(
                                content: Text('プロフィールを更新しました'),
                                behavior: SnackBarBehavior.floating,
                              ),
                            );
                          } else {
                            final newId =
                                'child_${DateTime.now().millisecondsSinceEpoch}';
                            onAddChild!(
                              ChildProfile(
                                id: newId,
                                name: name,
                                birthDate: birthDate,
                                gender: gender!,
                                iconIndex: iconIndex,
                                photoBytes: photoBytes,
                                themeColor: themeColor,
                                useCorrectedAge: useCorrectedAge,
                                expectedBirthDate: savedExpected,
                                fatherHeightCm: fatherHeight,
                                motherHeightCm: motherHeight,
                                // 出生時身長・体重が入力されていれば、
                                // 生まれた日の記録として最初の成長記録を自動登録。
                                growthRecords: _syncBirthRecord(
                                  const [],
                                  newId,
                                  birthDate,
                                  heightCm: birthHeight,
                                  weightKg: birthWeight,
                                ),
                              ),
                            );
                            Navigator.pop(sheetCtx);
                            ScaffoldMessenger.of(context).showSnackBar(
                              SnackBar(
                                content: Text('$nameを追加しました'),
                                behavior: SnackBarBehavior.floating,
                              ),
                            );
                          }
                        },
                        icon: Icon(
                          isEditing ? Icons.save_rounded : Icons.add_rounded,
                        ),
                        label: Text(isEditing ? '保存する' : '追加する'),
                        style: FilledButton.styleFrom(
                          padding: const EdgeInsets.symmetric(vertical: 14),
                          shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(14),
                          ),
                        ),
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 8),
              ],
            ),
          ),
        );
      },
    ),
  );
}

class ChildrenScreen extends StatelessWidget {
  const ChildrenScreen({
    super.key,
    this.embedded = false,
    required this.children,
    required this.onUpdateChild,
    required this.onAddChild,
    this.footer = const [],
  });

  final bool embedded;
  final List<ChildProfile> children;
  final void Function(int index, ChildProfile updated) onUpdateChild;
  final ValueChanged<ChildProfile> onAddChild;

  /// リスト末尾に追加で表示する項目（設定画面のヘルプ欄など）。
  final List<Widget> footer;

  void _showProfileModal(
    BuildContext context, {
    ChildProfile? editing,
    int? editingIndex,
  }) {
    showChildProfileModal(
      context,
      children: children,
      onUpdateChild: onUpdateChild,
      onAddChild: onAddChild,
      editing: editing,
      editingIndex: editingIndex,
    );
  }

  Widget _buildBody(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;

    // 大画面では設定項目が横に間延びしないよう幅を制限して中央寄せする。
    return Center(
      child: ConstrainedBox(
        constraints: const BoxConstraints(maxWidth: kContentMaxWidth),
        child: ListView(
          padding: EdgeInsets.fromLTRB(
            16,
            embedded ? 8 : 16,
            16,
            embedded ? 24 : 96,
          ),
          children: [
            // 「設定」タイトルは AppShell のヘッダー側に集約したため body では出さない。
            Card(
              color: scheme.primaryContainer.withValues(alpha: 0.3),
              child: Padding(
                padding: const EdgeInsets.all(16),
                child: Row(
                  children: [
                    Icon(Icons.family_restroom_rounded, color: scheme.primary),
                    const SizedBox(width: 12),
                    Expanded(
                      child: Text(
                        '登録済みのお子様：${children.length}人\n'
                        '✏️ アイコンをタップして編集できます',
                        style: TextStyle(
                          fontWeight: FontWeight.w600,
                          color: scheme.onSurface,
                          height: 1.5,
                        ),
                      ),
                    ),
                  ],
                ),
              ),
            ),
            const SizedBox(height: 16),
            ...List.generate(
              children.length,
              (index) => Padding(
                padding: const EdgeInsets.only(bottom: 12),
                child: ChildProfileTile(
                  child: children[index],
                  onEdit: () => _showProfileModal(
                    context,
                    editing: children[index],
                    editingIndex: index,
                  ),
                ),
              ),
            ),
            if (embedded) ...[
              const SizedBox(height: 8),
              if (children.length < 6)
                FilledButton.icon(
                  onPressed: () => _showProfileModal(context),
                  icon: const Icon(Icons.add_rounded),
                  label: const Text('お子様を追加する'),
                  style: FilledButton.styleFrom(
                    minimumSize: const Size.fromHeight(48),
                  ),
                )
              else
                OutlinedButton.icon(
                  onPressed: null,
                  icon: const Icon(Icons.group_rounded),
                  label: const Text('上限（6名）に達しています'),
                ),
            ],
            ...footer,
          ],
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    if (embedded) {
      return SafeArea(child: _buildBody(context));
    }

    final scheme = Theme.of(context).colorScheme;

    return Scaffold(
      appBar: AppBar(
        title: Text(
          'お子様プロフィール',
          style: TextStyle(
            fontWeight: FontWeight.bold,
            color: scheme.onPrimaryContainer,
          ),
        ),
        backgroundColor: scheme.primaryContainer,
        foregroundColor: scheme.onPrimaryContainer,
      ),
      floatingActionButton: children.length < 6
          ? FloatingActionButton.extended(
              onPressed: () => _showProfileModal(context),
              icon: const Icon(Icons.add_rounded),
              label: const Text('お子様を追加する'),
            )
          : FloatingActionButton.extended(
              onPressed: null,
              backgroundColor: scheme.surfaceContainerHighest,
              foregroundColor: scheme.onSurfaceVariant,
              icon: const Icon(Icons.group_rounded),
              label: const Text('上限（6名）に達しています'),
            ),
      body: _buildBody(context),
    );
  }
}

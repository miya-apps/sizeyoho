import 'dart:typed_data';
import 'dart:ui' as ui;

import 'package:flutter/material.dart';
import 'package:image_picker/image_picker.dart';
import 'package:intl/intl.dart';

import '../models/birthday_memory.dart';
import '../models/child_profile.dart';
import '../models/growth_record.dart';
import 'birthday_photo.dart';
import 'measurement_wheels.dart';

/// お誕生日の思い出（写真・サイズ・メモ）の編集ダイアログ。
/// お祝いダイアログ・「お誕生日の思い出」画面・履歴のマーカーから共通で使う。
///
/// 身長・体重は成長記録の入力フォームと同じホイール入力。
/// 自動では記録せず、トグルをONにした項目だけ保存する
/// （既存の思い出に値がある場合はONで起動）。
Future<void> showBirthdayMemoryEditDialog({
  required BuildContext context,
  required ChildProfile child,
  required int age,
  required void Function(ChildProfile updated) onUpdate,
}) {
  return showDialog<void>(
    context: context,
    builder: (dialogContext) => Dialog(
      backgroundColor:
          Theme.of(dialogContext).colorScheme.surfaceContainerLowest,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(24)),
      child: ConstrainedBox(
        constraints: const BoxConstraints(maxWidth: 420),
        child: SingleChildScrollView(
          child: _BirthdayMemoryEditForm(
            child: child,
            age: age,
            onUpdate: onUpdate,
          ),
        ),
      ),
    ),
  );
}

class _BirthdayMemoryEditForm extends StatefulWidget {
  const _BirthdayMemoryEditForm({
    required this.child,
    required this.age,
    required this.onUpdate,
  });

  final ChildProfile child;
  final int age;
  final void Function(ChildProfile updated) onUpdate;

  @override
  State<_BirthdayMemoryEditForm> createState() =>
      _BirthdayMemoryEditFormState();
}

class _BirthdayMemoryEditFormState extends State<_BirthdayMemoryEditForm> {
  /// 写真プレビュー（正方形）の一辺。
  static const double _photoPreviewSize = 180;

  BirthdayMemory? _existing;
  Uint8List? _photo;

  /// 正方形に切り取るときの表示位置（-1〜1）と拡大率（1〜4）。
  double _alignX = 0.0;
  double _alignY = 0.0;
  double _scale = 1.0;

  /// 写真の縦横比（幅/高さ）。切り取り調整ダイアログで
  /// 「実寸の写真」の大きさを決めるのに使う。null は未取得（調整不可）。
  double? _photoAspect;

  late final TextEditingController _noteCtl;

  /// メモ欄フォーカス時に、キーボードで隠れないよう自動スクロールするためのキー。
  final _noteKey = GlobalKey();
  final _noteFocus = FocusNode();

  bool _heightEnabled = false;
  bool _weightEnabled = false;
  late int _hIndex;
  late int _wIndex;
  late final FixedExtentScrollController _hCtrl;
  late final FixedExtentScrollController _wCtrl;

  @override
  void initState() {
    super.initState();
    for (final m in widget.child.birthdayMemories) {
      if (m.age == widget.age) _existing = m;
    }
    _photo = _existing?.photoBytes;
    _alignX = _existing?.photoAlignX ?? 0.0;
    _alignY = _existing?.photoAlignY ?? 0.0;
    _scale = _existing?.photoScale ?? 1.0;
    if (_photo != null) _loadPhotoAspect(_photo!);
    _noteCtl = TextEditingController(text: _existing?.note ?? '');

    // 既存の思い出に値がある項目だけON。新規は両方OFF（自動では記録しない）。
    _heightEnabled = _existing?.heightCm != null;
    _weightEnabled = _existing?.weightKg != null;

    // ホイールの初期位置：既存値 → その誕生日に近い成長記録 → 既定値。
    // （位置合わせのためだけで、トグルOFFのままなら保存されない）
    final near = _recordNearBirthday();
    _hIndex = heightWheelIndexOf(
      _existing?.heightCm ?? near?.heightCm ?? 80.0,
    );
    _wIndex = weightWheelIndexOf(
      _existing?.weightKg ?? near?.weightKg ?? 10.0,
    );
    _hCtrl = FixedExtentScrollController(initialItem: _hIndex);
    _wCtrl = FixedExtentScrollController(initialItem: _wIndex);

    // メモ欄にフォーカスしたら、キーボード表示でダイアログが縮んだあとに
    // メモ欄が見える位置までスクロールする（写真で縦に伸びていると
    // 初期状態ではメモ欄が視界の外になるため）。
    _noteFocus.addListener(_onNoteFocusChanged);
  }

  void _onNoteFocusChanged() {
    if (!_noteFocus.hasFocus) return;
    // キーボードの出現アニメーション完了を待ってからスクロールする。
    Future.delayed(const Duration(milliseconds: 400), () {
      final ctx = _noteKey.currentContext;
      if (!mounted || ctx == null || !ctx.mounted || !_noteFocus.hasFocus) {
        return;
      }
      Scrollable.ensureVisible(
        ctx,
        alignment: 0.5,
        duration: const Duration(milliseconds: 200),
        curve: Curves.easeOut,
      );
    });
  }

  @override
  void dispose() {
    _noteFocus.removeListener(_onNoteFocusChanged);
    _noteFocus.dispose();
    _noteCtl.dispose();
    _hCtrl.dispose();
    _wCtrl.dispose();
    super.dispose();
  }

  /// この誕生日（[widget.age] 歳）にいちばん近い成長記録を返す。
  /// 記録がまったく無ければ null。
  GrowthRecord? _recordNearBirthday() {
    final records = widget.child.growthRecords;
    if (records.isEmpty) return null;
    final b = widget.child.birthDate;
    final birthday = DateTime(b.year + widget.age, b.month, b.day);
    GrowthRecord? best;
    var bestDays = 1 << 30;
    for (final r in records) {
      final days = r.date.difference(birthday).inDays.abs();
      if (days < bestDays) {
        bestDays = days;
        best = r;
      }
    }
    return best;
  }

  Future<void> _pickPhoto() async {
    // 表示は最大でも400px四方程度なので、1000px・品質75で十分きれい。
    // データは端末内に保存されるため、容量を抑えることを優先する。
    final XFile? xf = await ImagePicker().pickImage(
      source: ImageSource.gallery,
      maxWidth: 1000,
      maxHeight: 1000,
      imageQuality: 75,
    );
    if (xf == null) return;
    final bytes = await xf.readAsBytes();
    setState(() {
      _photo = bytes;
      // 新しい写真は中央・等倍から。
      _alignX = 0.0;
      _alignY = 0.0;
      _scale = 1.0;
      _photoAspect = null;
    });
    await _loadPhotoAspect(bytes);
  }

  /// 写真の縦横比を取得する。切り取り調整ダイアログで
  /// 「写真の実寸」を決めるのに必要（取得できたら調整を有効にする）。
  Future<void> _loadPhotoAspect(Uint8List bytes) async {
    try {
      final codec = await ui.instantiateImageCodec(bytes);
      final frame = await codec.getNextFrame();
      final aspect = frame.image.width / frame.image.height;
      frame.image.dispose();
      codec.dispose();
      if (!mounted || _photo == null) return;
      setState(() => _photoAspect = aspect);
    } catch (_) {
      // 読み取れない場合は調整不可（表示は中央固定）。
    }
  }

  /// 切り取り調整ダイアログ（ピンチで拡大縮小・ドラッグで移動）を開く。
  Future<void> _openCropAdjust() async {
    final aspect = _photoAspect;
    final photo = _photo;
    if (aspect == null || photo == null) return;
    final result = await showDialog<({double alignX, double alignY, double scale})>(
      context: context,
      builder: (_) => _CropAdjustDialog(
        bytes: photo,
        aspect: aspect,
        alignX: _alignX,
        alignY: _alignY,
        scale: _scale,
      ),
    );
    if (result == null || !mounted) return;
    setState(() {
      _alignX = result.alignX;
      _alignY = result.alignY;
      _scale = result.scale;
    });
  }

  void _save() {
    final note = _noteCtl.text.trim();
    final isEmpty = _photo == null &&
        !_heightEnabled &&
        !_weightEnabled &&
        note.isEmpty;

    // すべて空なら中身のない思い出を残さない（既存があれば削除扱い）。
    final memories = [
      ...widget.child.birthdayMemories.where((m) => m.age != widget.age),
      if (!isEmpty)
        BirthdayMemory(
          age: widget.age,
          savedAt: DateTime.now(),
          photoBytes: _photo,
          photoAlignX: _alignX,
          photoAlignY: _alignY,
          photoScale: _scale,
          heightCm: _heightEnabled ? heightCmAtWheelIndex(_hIndex) : null,
          weightKg: _weightEnabled ? weightKgAtWheelIndex(_wIndex) : null,
          note: note.isEmpty ? null : note,
        ),
    ]..sort((a, b) => a.age.compareTo(b.age));
    widget.onUpdate(widget.child.copyWith(birthdayMemories: memories));
    Navigator.of(context).pop();
  }

  /// この年齢の思い出を丸ごと削除する（確認ダイアログ付き）。
  Future<void> _delete() async {
    final scheme = Theme.of(context).colorScheme;
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (dialogCtx) => AlertDialog(
        title: Text('${widget.age}歳の思い出を削除'),
        content: const Text('写真・サイズ・メモをすべて削除しますか？'),
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
    if (confirmed != true || !mounted) return;

    final memories = widget.child.birthdayMemories
        .where((m) => m.age != widget.age)
        .toList();
    widget.onUpdate(widget.child.copyWith(birthdayMemories: memories));
    Navigator.of(context).pop();
  }

  /// 写真下の操作ボタン（アイコン＋短いラベル）。
  Widget _photoAction({
    required IconData icon,
    required String label,
    required Color color,
    required VoidCallback? onTap,
  }) {
    final c = onTap == null ? Colors.grey[400]! : color;
    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(8),
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(icon, size: 20, color: c),
            const SizedBox(height: 2),
            Text(
              label,
              style: TextStyle(
                fontSize: 10,
                fontWeight: FontWeight.w600,
                color: c,
              ),
            ),
          ],
        ),
      ),
    );
  }

  /// 体重ホイール下の g 換算表示（記録フォームと同じ仕様）。
  Widget _weightFooter(ColorScheme scheme) {
    final kg = weightKgAtWheelIndex(_wIndex);
    final show = kg < weightGramNoteMaxKg;
    return SizedBox(
      height: 16,
      child: show
          ? Text(
              '= ${NumberFormat('#,##0').format((kg * 1000).round())} g',
              style: TextStyle(
                fontSize: 11,
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

    return Padding(
      padding: const EdgeInsets.fromLTRB(24, 20, 24, 16),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Text(
            '🎂 ${widget.age}歳のお誕生日の思い出',
            style: TextStyle(
              fontSize: 16,
              fontWeight: FontWeight.w700,
              color: scheme.onSurface,
            ),
          ),
          Text(
            widget.child.displayName,
            style: TextStyle(fontSize: 13, color: scheme.onSurfaceVariant),
          ),
          const SizedBox(height: 14),
          // 写真：一覧・お祝いと同じ「正方形の切り取り」でプレビューする。
          // タップで調整ダイアログを開き、ピンチ・ドラッグで切り取りを決める。
          if (_photo != null) ...[
            Center(
              child: SizedBox(
                width: _photoPreviewSize,
                child: InkWell(
                  onTap: _openCropAdjust,
                  borderRadius: BorderRadius.circular(12),
                  child: BirthdayPhoto(
                    bytes: _photo!,
                    alignX: _alignX,
                    alignY: _alignY,
                    scale: _scale,
                  ),
                ),
              ),
            ),
            const SizedBox(height: 6),
            // 幅の狭い端末でも見切れないよう、アイコン＋短いラベルで並べる。
            Row(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                _photoAction(
                  icon: Icons.crop_rounded,
                  label: '切り取り',
                  color: scheme.primary,
                  onTap: _photoAspect == null ? null : _openCropAdjust,
                ),
                const SizedBox(width: 18),
                _photoAction(
                  icon: Icons.photo_library_outlined,
                  label: '変更',
                  color: scheme.primary,
                  onTap: _pickPhoto,
                ),
                const SizedBox(width: 18),
                _photoAction(
                  icon: Icons.delete_outline,
                  label: '削除',
                  color: Colors.grey[700]!,
                  onTap: () => setState(() => _photo = null),
                ),
              ],
            ),
          ] else
            InkWell(
              onTap: _pickPhoto,
              borderRadius: BorderRadius.circular(12),
              child: Container(
                height: 88,
                decoration: BoxDecoration(
                  color: scheme.primary.withValues(alpha: 0.05),
                  borderRadius: BorderRadius.circular(12),
                  border: Border.all(
                    color: scheme.primary.withValues(alpha: 0.3),
                  ),
                ),
                child: Column(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    Icon(Icons.add_a_photo_outlined,
                        size: 22, color: scheme.primary),
                    const SizedBox(height: 4),
                    Text(
                      '写真を選ぶ',
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
          const SizedBox(height: 12),
          // 身長・体重：成長記録の入力フォームと同じホイール＋トグル。
          Row(
            mainAxisAlignment: MainAxisAlignment.center,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              MeasurementPickerColumn(
                label: '身長',
                unit: 'cm',
                wheel: MeasurementValueWheel(
                  controller: _hCtrl,
                  itemCount: heightWheelItemCount,
                  labelAt: heightWheelLabelAt,
                  onChanged: (i) => _hIndex = i,
                ),
                enabled: _heightEnabled,
                onToggle: (v) => setState(() => _heightEnabled = v),
                toggleColor: widget.child.themeColor,
              ),
              const SizedBox(width: 20),
              MeasurementPickerColumn(
                label: '体重',
                unit: 'kg',
                wheel: MeasurementValueWheel(
                  controller: _wCtrl,
                  itemCount: weightWheelItemCount,
                  labelAt: weightWheelLabelAt,
                  onChanged: (i) => setState(() => _wIndex = i),
                ),
                enabled: _weightEnabled,
                onToggle: (v) => setState(() => _weightEnabled = v),
                toggleColor: widget.child.themeColor,
                footer: _weightFooter(scheme),
              ),
            ],
          ),
          const SizedBox(height: 14),
          TextField(
            key: _noteKey,
            controller: _noteCtl,
            focusNode: _noteFocus,
            maxLines: 2,
            maxLength: 200,
            // スクロール時に保存ボタンまで一緒に見えるよう下に余白を取る。
            scrollPadding: const EdgeInsets.only(bottom: 120),
            decoration: InputDecoration(
              labelText: 'メモ',
              hintText: '例：電車が大好きな1年でした',
              hintStyle: TextStyle(fontSize: 12.5, color: Colors.grey[400]),
              border: OutlineInputBorder(
                borderRadius: BorderRadius.circular(10),
              ),
              alignLabelWithHint: true,
              isDense: true,
            ),
          ),
          const SizedBox(height: 8),
          Row(
            children: [
              // 既存の思い出があるときだけ、丸ごと削除できるようにする。
              if (_existing != null)
                IconButton(
                  onPressed: _delete,
                  icon: const Icon(Icons.delete_outline),
                  color: scheme.error,
                  tooltip: 'この思い出を削除',
                ),
              const Spacer(),
              TextButton(
                onPressed: () => Navigator.of(context).pop(),
                child: const Text('キャンセル'),
              ),
              const SizedBox(width: 4),
              FilledButton(onPressed: _save, child: const Text('保存')),
            ],
          ),
        ],
      ),
    );
  }
}

/// 写真の切り取り調整ダイアログ。
/// 正方形の枠の中で、ピンチで拡大縮小・ドラッグで位置を動かして
/// 「うつす範囲」を決める（スマホの写真アプリと同じ操作感）。
class _CropAdjustDialog extends StatefulWidget {
  const _CropAdjustDialog({
    required this.bytes,
    required this.aspect,
    required this.alignX,
    required this.alignY,
    required this.scale,
  });

  final Uint8List bytes;

  /// 写真の縦横比（幅/高さ）。
  final double aspect;

  final double alignX;
  final double alignY;
  final double scale;

  @override
  State<_CropAdjustDialog> createState() => _CropAdjustDialogState();
}

class _CropAdjustDialogState extends State<_CropAdjustDialog> {
  static const double _maxScale = 4.0;

  final _ctrl = TransformationController();

  /// 正方形ビューポートの一辺。行列⇔切り取り値の換算に使うため、
  /// 画面幅から一度だけ決めて固定する。
  late final double _viewport;
  var _initialized = false;

  /// 写真を枠いっぱい（cover・等倍）に置いたときの描画サイズ。
  ({double w, double h}) get _coverSize => widget.aspect >= 1
      ? (w: _viewport * widget.aspect, h: _viewport)
      : (w: _viewport, h: _viewport / widget.aspect);

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    if (_initialized) return;
    _initialized = true;
    // ダイアログの外側余白・内側パディングを差し引いた幅に収める。
    final screenW = MediaQuery.sizeOf(context).width;
    _viewport = (screenW - 112).clamp(180.0, 280.0);
    // 保存済みの切り取り位置・倍率を初期表示に反映する。
    // align=-1 が写真の左（上）端、+1 が右（下）端に対応する平行移動量。
    final base = _coverSize;
    final s = widget.scale.clamp(1.0, _maxScale);
    final tx = (_viewport - s * base.w) * (widget.alignX + 1) / 2;
    final ty = (_viewport - s * base.h) * (widget.alignY + 1) / 2;
    _ctrl.value = Matrix4.identity()
      ..translateByDouble(tx, ty, 0, 1)
      ..scaleByDouble(s, s, s, 1);
  }

  @override
  void dispose() {
    _ctrl.dispose();
    super.dispose();
  }

  /// 現在の変換行列から切り取り位置・倍率を読み取って返す。
  ({double alignX, double alignY, double scale}) _readCrop() {
    final base = _coverSize;
    final m = _ctrl.value;
    final s = m.getMaxScaleOnAxis().clamp(1.0, _maxScale);
    final t = m.getTranslation();
    // 描画サイズが枠とほぼ同じ軸は動かせない（中央固定扱い）。
    double alignOf(double translation, double drawn) => drawn <= _viewport + 0.5
        ? 0.0
        : (2 * translation / (_viewport - drawn) - 1).clamp(-1.0, 1.0);
    return (
      alignX: alignOf(t.x, s * base.w),
      alignY: alignOf(t.y, s * base.h),
      scale: s,
    );
  }

  @override
  Widget build(BuildContext context) {
    final base = _coverSize;
    return Dialog(
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
      child: Padding(
        padding: const EdgeInsets.fromLTRB(16, 16, 16, 8),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            const Text(
              '切り取りの調整',
              style: TextStyle(fontSize: 14, fontWeight: FontWeight.w700),
            ),
            const SizedBox(height: 2),
            Text(
              'ピンチで拡大縮小・ドラッグで位置を調整',
              style: TextStyle(fontSize: 11, color: Colors.grey[700]),
            ),
            const SizedBox(height: 10),
            ClipRRect(
              borderRadius: BorderRadius.circular(12),
              child: SizedBox(
                width: _viewport,
                height: _viewport,
                child: InteractiveViewer(
                  transformationController: _ctrl,
                  constrained: false,
                  minScale: 1.0,
                  maxScale: _maxScale,
                  child: Image.memory(
                    widget.bytes,
                    width: base.w,
                    height: base.h,
                    fit: BoxFit.fill,
                    gaplessPlayback: true,
                  ),
                ),
              ),
            ),
            const SizedBox(height: 4),
            Row(
              children: [
                TextButton(
                  onPressed: () =>
                      setState(() => _ctrl.value = Matrix4.identity()),
                  child: Text(
                    'リセット',
                    style: TextStyle(fontSize: 12, color: Colors.grey[700]),
                  ),
                ),
                const Spacer(),
                TextButton(
                  onPressed: () => Navigator.of(context).pop(),
                  child: const Text('キャンセル'),
                ),
                const SizedBox(width: 4),
                FilledButton(
                  onPressed: () => Navigator.of(context).pop(_readCrop()),
                  child: const Text('決定'),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }
}

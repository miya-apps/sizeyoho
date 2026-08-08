import 'dart:typed_data';

import 'package:file_saver/file_saver.dart';
import 'package:flutter/material.dart';
import 'package:share_plus/share_plus.dart';

import '../export/guide_export_cards.dart';
import '../models/child_profile.dart';
import '../monetization/pro_paywall.dart';
import '../monetization/pro_status.dart';
import '../settings/export_privacy.dart';

/// 画像の保存・シェア画面。
///
/// ヘッダー左上の「画像保存」から開く全画面プレビュー。保存前に完成品が
/// そのまま見えるのが狙いで、
/// - 上部のチップ or 左右スワイプで5種類（成長曲線・SDスコア・おむつ・
///   洋服・靴）を切り替え
/// - 背景カラーと「名前を表示」のON/OFFをその場で変更（プレビューに即反映）
/// - 保存（1枚 / 全部）とシェア（端末の共有シート）を大きなボタンで実行
/// できる。画像の保存・シェアはPro版の機能（プレビューまでは無料で見られ、
/// 実行時にペイウォールを開く）。受診レポート（PDF）は無料のまま、
/// この画面の下部に入り口を置く。
class ExportPreviewScreen extends StatefulWidget {
  const ExportPreviewScreen({
    super.key,
    required this.child,
    required this.items,
    required this.initialItem,
    required this.fileNameFor,
    required this.onExportPdf,
  });

  final ChildProfile child;

  /// 切り替えられる書き出し対象（おむつガイドOFFの子では「おむつ」を除く）。
  final List<SizeExportItem> items;

  /// 開いた時点で表示するページ（見ていた画面に対応する項目）。
  final SizeExportItem initialItem;

  /// 保存ファイル名（拡張子なし）。名前伏せ設定の反映は呼び出し側が行う。
  final String Function(SizeExportItem item) fileNameFor;

  /// 受診レポート（PDF）の出力処理（無料機能）。
  final Future<void> Function() onExportPdf;

  @override
  State<ExportPreviewScreen> createState() => _ExportPreviewScreenState();
}

class _ExportPreviewScreenState extends State<ExportPreviewScreen> {
  late final PageController _pageController;
  late int _index;

  /// 選択中の背景カラー（[_bgOptions] のインデックス）。
  int _bgIndex = 0;

  /// 画像に名前を載せるか。OFFならアイコンだけの匿名見出しになる。
  ///
  /// この設定の唯一の入り口（設定画面のスイッチは廃止）。切り替えると
  /// [ExportPrivacy] に保存され、受診レポート（PDF）とファイル名の
  /// 「第一子」などの匿名表記にも反映される。
  late bool _showName;

  /// 保存・シェアの実行中（ボタンの二度押し防止）。
  bool _busy = false;

  @override
  void initState() {
    super.initState();
    _index = widget.items.indexOf(widget.initialItem).clamp(
          0,
          widget.items.length - 1,
        );
    _pageController = PageController(initialPage: _index);
    _showName = !ExportPrivacy.maskNames.value;
  }

  @override
  void dispose() {
    _pageController.dispose();
    super.dispose();
  }

  SizeExportItem get _currentItem => widget.items[_index];

  /// 選べる背景カラー。先頭（既定）はその子のテーマ淡色で、
  /// ほかは子どものテーマに寄らない定番のうすいパステル。
  List<(String, Color)> get _bgOptions => [
        ('テーマ', defaultExportBackground(widget.child)),
        ('しろ', Colors.white),
        ('ピンク', const Color(0xFFFBECEF)),
        ('ブルー', const Color(0xFFEAF1F8)),
        ('グリーン', const Color(0xFFEAF4EC)),
      ];

  Color get _background => _bgOptions[_bgIndex].$2;

  void _showSnack(String message) {
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(content: Text(message), behavior: SnackBarBehavior.floating),
    );
  }

  /// プレビューと同じ設定（背景色・名前表示）で1枚ぶんのPNGを生成する。
  Future<Uint8List?> _capture(SizeExportItem item) {
    return captureGuideSquareImage(
      context: context,
      item: item,
      child: widget.child,
      maskName: !_showName,
      background: _background,
    );
  }

  /// 保存・シェアの共通ガード。Pro未加入ならペイウォールを開いて false。
  bool _ensureProAndIdle() {
    if (_busy) return false;
    if (!ProStatus.isPro.value) {
      showProPaywallSheet(context);
      return false;
    }
    return true;
  }

  Future<void> _save(List<SizeExportItem> items) async {
    if (!_ensureProAndIdle()) return;
    setState(() => _busy = true);
    var saved = 0;
    try {
      for (final item in items) {
        if (!mounted) return;
        final bytes = await _capture(item);
        if (bytes == null) {
          if (mounted) {
            _showSnack('${sizeExportItemLabel(item)}の画像の生成に失敗しました');
          }
          continue;
        }
        try {
          await FileSaver.instance.saveFile(
            name: widget.fileNameFor(item),
            bytes: bytes,
            fileExtension: 'png',
            mimeType: MimeType.png,
          );
          saved++;
        } on Exception {
          if (mounted) {
            _showSnack('${sizeExportItemLabel(item)}の画像の保存に失敗しました');
          }
        }
      }
    } finally {
      if (mounted) setState(() => _busy = false);
    }
    if (mounted && saved > 0) {
      _showSnack(saved == 1 ? '画像を保存しました' : '$saved枚の画像を保存しました');
    }
  }

  /// 表示中の1枚を端末の共有シートに渡す（LINE・Instagram等へ直接）。
  /// 共有シートが使えない環境（一部のブラウザ等）では保存を案内する。
  Future<void> _share() async {
    if (!_ensureProAndIdle()) return;
    setState(() => _busy = true);
    try {
      final item = _currentItem;
      final bytes = await _capture(item);
      if (bytes == null) {
        if (mounted) _showSnack('画像の生成に失敗しました');
        return;
      }
      final name = '${widget.fileNameFor(item)}.png';
      await SharePlus.instance.share(
        ShareParams(
          files: [XFile.fromData(bytes, mimeType: 'image/png')],
          fileNameOverrides: [name],
        ),
      );
    } on Exception {
      if (mounted) {
        _showSnack('この環境ではシェアを開けませんでした。保存してから共有アプリで送ってください');
      }
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  Future<void> _exportPdf() async {
    if (_busy) return;
    setState(() => _busy = true);
    try {
      await widget.onExportPdf();
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  void _goTo(int index) {
    _pageController.animateToPage(
      index,
      duration: const Duration(milliseconds: 250),
      curve: Curves.easeOut,
    );
  }

  /// 上部の種類切り替えチップ。
  /// 5種類が必ず1行に収まるようコンパクトにし、狭い画面では
  /// FittedBox で全体をわずかに縮小する（横スクロールにはしない）。
  Widget _buildItemChips(ColorScheme scheme) {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 8),
      child: FittedBox(
        fit: BoxFit.scaleDown,
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            for (int i = 0; i < widget.items.length; i++)
              Padding(
                padding: const EdgeInsets.symmetric(horizontal: 2),
                child: ChoiceChip(
                  label: Text(sizeExportItemLabel(widget.items[i])),
                  labelStyle: TextStyle(
                    fontSize: 12.5,
                    fontWeight: FontWeight.w600,
                    color: i == _index ? Colors.white : Colors.grey[800],
                  ),
                  labelPadding: const EdgeInsets.symmetric(horizontal: 6),
                  visualDensity: VisualDensity.compact,
                  materialTapTargetSize: MaterialTapTargetSize.shrinkWrap,
                  selected: i == _index,
                  showCheckmark: false,
                  selectedColor: scheme.primary,
                  onSelected: (_) => _goTo(i),
                ),
              ),
          ],
        ),
      ),
    );
  }

  /// 未課金ユーザーのプレビューに重ねる透かし。
  ///
  /// スクショの完全な禁止は iOS・Web では技術的にできないため、
  /// 「プレビューをスクショすれば保存機能が要らなくなる」抜け道は
  /// 透かしで塞ぐ（Pro版では表示されず、保存・シェアした画像にも入らない）。
  Widget _sampleWatermark() {
    return Positioned.fill(
      child: IgnorePointer(
        child: Center(
          child: Transform.rotate(
            angle: -0.5,
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                Text(
                  'サンプル',
                  style: TextStyle(
                    fontSize: 52,
                    fontWeight: FontWeight.w900,
                    letterSpacing: 6,
                    color: Colors.grey.withValues(alpha: 0.30),
                  ),
                ),
                Text(
                  'Pro版で透かしなしの画像を保存・シェアできます',
                  style: TextStyle(
                    fontSize: 12,
                    fontWeight: FontWeight.w700,
                    color: Colors.grey.withValues(alpha: 0.40),
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }

  /// 完成品プレビュー（保存されるものと同じレイアウト・背景色）。
  Widget _buildPreviewPage(SizeExportItem item, {required bool isPro}) {
    return Center(
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 8),
        child: AspectRatio(
          aspectRatio: 1,
          child: DecoratedBox(
            decoration: BoxDecoration(
              borderRadius: BorderRadius.circular(14),
              boxShadow: [
                BoxShadow(
                  color: Colors.black.withValues(alpha: 0.14),
                  blurRadius: 18,
                  offset: const Offset(0, 6),
                ),
              ],
            ),
            child: ClipRRect(
              // 角丸は画面上の見栄えだけ。保存されるPNGは四隅まで背景色。
              borderRadius: BorderRadius.circular(14),
              child: Stack(
                children: [
                  Container(
                    color: _background,
                    child: FittedBox(
                      fit: BoxFit.contain,
                      child: SizedBox(
                        width: GuideExportCard.designWidth,
                        height: GuideExportCard.designWidth,
                        child: GuideExportCard(
                          item: item,
                          child: widget.child,
                          maskName: !_showName,
                        ),
                      ),
                    ),
                  ),
                  if (!isPro) _sampleWatermark(),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }

  /// 背景カラーの選択サークルと「名前を表示」トグル。
  Widget _buildOptions(ColorScheme scheme) {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 20),
      child: Column(
        children: [
          Row(
            children: [
              Text(
                '背景カラー',
                style: TextStyle(
                  fontSize: 12.5,
                  fontWeight: FontWeight.w600,
                  color: Colors.grey[700],
                ),
              ),
              const Spacer(),
              for (int i = 0; i < _bgOptions.length; i++)
                Padding(
                  padding: const EdgeInsets.only(left: 10),
                  child: Tooltip(
                    message: _bgOptions[i].$1,
                    child: GestureDetector(
                      onTap: () => setState(() => _bgIndex = i),
                      child: Container(
                        width: 32,
                        height: 32,
                        decoration: BoxDecoration(
                          color: _bgOptions[i].$2,
                          shape: BoxShape.circle,
                          border: Border.all(
                            color: i == _bgIndex
                                ? scheme.primary
                                : Colors.grey[400]!,
                            width: i == _bgIndex ? 2.5 : 1,
                          ),
                        ),
                        child: i == _bgIndex
                            ? Icon(
                                Icons.check_rounded,
                                size: 16,
                                color: Color.lerp(
                                  scheme.primary,
                                  Colors.black,
                                  0.3,
                                ),
                              )
                            : null,
                      ),
                    ),
                  ),
                ),
            ],
          ),
          const SizedBox(height: 2),
          Row(
            children: [
              Text(
                '名前を表示',
                style: TextStyle(
                  fontSize: 12.5,
                  fontWeight: FontWeight.w600,
                  color: Colors.grey[700],
                ),
              ),
              const SizedBox(width: 6),
              // 狭い画面でも途切れないよう、収まらないときは縮小して1行に収める。
              Expanded(
                child: Align(
                  alignment: Alignment.centerLeft,
                  child: FittedBox(
                    fit: BoxFit.scaleDown,
                    child: Text(
                      _showName ? '' : '画像はアイコンのみ・PDFは「第一子」表記',
                      maxLines: 1,
                      softWrap: false,
                      style:
                          TextStyle(fontSize: 10.5, color: Colors.grey[600]),
                    ),
                  ),
                ),
              ),
              Switch(
                value: _showName,
                onChanged: (v) {
                  setState(() => _showName = v);
                  // 設定として保存し、PDF・ファイル名の匿名表記にも反映する。
                  ExportPrivacy.setEnabled(!v);
                },
              ),
            ],
          ),
        ],
      ),
    );
  }

  /// ボタンの文字。狭い画面でも2行に折り返さず、収まらないときだけ縮小する。
  static Widget _buttonLabel(String text) => FittedBox(
        fit: BoxFit.scaleDown,
        child: Text(text, maxLines: 1, softWrap: false),
      );

  /// 保存・シェア・PDFのボタン群。
  /// 上段＝表示中の1枚への操作（濃い色）、下段＝まとめ・別形式（枠線）。
  /// 4つのボタンの共通部品。見た目（トーン）は4つとも同じにし、
  /// 機能の違いはアイコンで見分けられるようにする。
  /// 鍵アイコンへの差し替えはしない（差し替えると3つが同じ見た目になる。
  /// Pro案内はプレビューの透かしとタップ時のペイウォールで伝わる）。
  Widget _actionButton({
    required IconData icon,
    required String label,
    required VoidCallback onPressed,
  }) {
    return FilledButton.tonalIcon(
      style: FilledButton.styleFrom(
        padding: const EdgeInsets.symmetric(horizontal: 10),
      ),
      onPressed: _busy ? null : onPressed,
      icon: Icon(icon, size: 18),
      label: _buttonLabel(label),
    );
  }

  Widget _buildActions() {
    return Padding(
      padding: const EdgeInsets.fromLTRB(20, 6, 20, 10),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Row(
            children: [
              Expanded(
                child: _actionButton(
                  icon: Icons.download_rounded,
                  label: 'この画像を保存',
                  onPressed: () => _save([_currentItem]),
                ),
              ),
              const SizedBox(width: 10),
              Expanded(
                child: _actionButton(
                  // シェアはOS標準の形（Android=共有ノード／iOS=箱と矢印）。
                  icon: Icons.adaptive.share,
                  label: 'シェア',
                  onPressed: _share,
                ),
              ),
            ],
          ),
          const SizedBox(height: 8),
          Row(
            children: [
              Expanded(
                child: _actionButton(
                  icon: Icons.collections_outlined,
                  label: '${widget.items.length}枚すべて保存',
                  onPressed: () => _save(widget.items),
                ),
              ),
              const SizedBox(width: 10),
              Expanded(
                child: _actionButton(
                  icon: Icons.picture_as_pdf_outlined,
                  label: '受診レポートPDF',
                  onPressed: _exportPdf,
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    return Scaffold(
      appBar: AppBar(
        // タイトルの見た目は他のプッシュ画面（Q&A・思い出など）と統一。
        title: const Text(
          '画像の保存・シェア',
          style: TextStyle(fontSize: 17, fontWeight: FontWeight.w700),
        ),
        centerTitle: true,
        leading: IconButton(
          icon: const Icon(Icons.close_rounded),
          tooltip: '閉じる',
          onPressed: () => Navigator.of(context).pop(),
        ),
      ),
      // Pro状態を購読して、この画面を開いたままPro版を購入した場合も
      // 透かしと鍵アイコンがすぐ消えるようにする。
      body: ValueListenableBuilder<bool>(
        valueListenable: ProStatus.isPro,
        builder: (context, isPro, _) => SafeArea(
          child: Column(
            children: [
              const SizedBox(height: 4),
              _buildItemChips(scheme),
              Expanded(
                child: PageView.builder(
                  controller: _pageController,
                  itemCount: widget.items.length,
                  onPageChanged: (i) => setState(() => _index = i),
                  itemBuilder: (_, i) =>
                      _buildPreviewPage(widget.items[i], isPro: isPro),
                ),
              ),
              _buildOptions(scheme),
              _buildActions(),
              if (_busy) const LinearProgressIndicator(minHeight: 2),
            ],
          ),
        ),
      ),
    );
  }
}

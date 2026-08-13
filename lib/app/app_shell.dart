import 'package:file_saver/file_saver.dart';
import 'package:flutter/material.dart';
import 'package:phosphoricons_flutter/phosphoricons_flutter.dart';
import 'package:shared_preferences/shared_preferences.dart';

import 'adaptive_layout.dart';
import '../ads/ad_banner.dart';
import '../cloud/cloud_backup.dart';
import '../export/growth_pdf.dart';
import '../export/guide_export_cards.dart';
import '../export/save_to_device.dart';
import '../export/screen_capture.dart';
import '../models/child_profile.dart';

import '../models/gender.dart';
import '../monetization/pro_status.dart';
import '../models/growth_record.dart';
import '../settings/export_privacy.dart';

import '../repositories/child_repository.dart';

import '../screens/birthday_memories_screen.dart';
import '../screens/children_screen.dart';
import '../screens/clothing_guide_screen.dart';
import '../screens/export_preview_screen.dart';
import '../screens/growth_home_screen.dart';

import '../screens/record_history_screen.dart';

import '../screens/settings_screen.dart';

import '../widgets/birthday_celebration_dialog.dart';
import '../widgets/growth_summary_sheet.dart';

import '../theme/app_theme.dart';

import '../widgets/growth_record_add_sheet.dart';

class AppShell extends StatefulWidget {
  const AppShell({super.key});

  @override
  State<AppShell> createState() => _AppShellState();
}

class _AppShellState extends State<AppShell> {
  final ChildRepository _repository = LocalChildRepository();

  /// 画面背景に敷く選択中テーマ色の不透明度。
  static const double _screenBackgroundAlpha = 0.10;

  int _selectedChildIndex = 0;

  // 起動時は「グラフ」タブを初期表示する。
  int _tabIndex = 0;

  // 設定画面（index 3）から戻る先のコンテンツタブ（グラフ/履歴/洋服ガイド）。
  int _lastContentTabIndex = 0;

  final GlobalKey<RecordHistoryScreenState> _historyScreenKey =
      GlobalKey<RecordHistoryScreenState>();

  /// グラフタブで表示中のグラフ種類（0=成長曲線, 1=SDスコア）。
  /// ヘッダー右上のトグルと GrowthHomeScreen の PageView を双方向同期する。
  final ValueNotifier<int> _graphChartType = ValueNotifier<int>(0);

  /// 「サイズ予報」タブ内で表示中のサブタブ（おむつ/洋服/靴）。
  /// ClothingGuideScreen から毎フレーム同期され、ヘッダーの「画像保存」
  /// ボタンの文言・書き出し対象をこれに合わせて切り替える。
  final ValueNotifier<GuideSizeTab> _guideMode =
      ValueNotifier<GuideSizeTab>(GuideSizeTab.clothing);

  @override
  void dispose() {
    _graphChartType.dispose();
    _guideMode.dispose();
    super.dispose();
  }

  /// 設定画面のニュートラル背景色（特定の子のテーマ色を使わない）。
  static const Color _settingsBackground = Color(0xFFF6F6F8);

  static const int _settingsTabIndex = 3;

  bool get _isSettings => _tabIndex == _settingsTabIndex;

  // ── 初回の使い方ガイド（コーチマーク） ──
  /// 表示中のガイドステップ（null なら非表示）。
  int? _guideStep;

  /// ガイドを最後まで見た／スキップしたら true を永続化し、以後は出さない。
  static const String _kGuideDoneKey = 'onboarding_guide_done_v1';

  // ── チュートリアルのスポットライト対象（実UIの位置取得用キー） ──
  final GlobalKey _guideFabKey = GlobalKey();
  final GlobalKey _guideHeaderLeftKey = GlobalKey();
  final GlobalKey _guideHeaderRightKey = GlobalKey();
  final GlobalKey _guideChildSwitcherKey = GlobalKey();
  final GlobalKey _guideTabHistoryKey = GlobalKey();
  final GlobalKey _guideTabClothingKey = GlobalKey();
  final GlobalKey _guideTabSettingsKey = GlobalKey();

  /// ガイドの各ステップが指す実UIのキー（null なら全面スクリムのみ）。
  GlobalKey? _guideTargetKey(int step) => switch (step) {
        0 => _guideFabKey,
        2 => _guideHeaderRightKey,
        3 => _guideHeaderLeftKey,
        4 => _guideTabHistoryKey,
        5 => _guideTabClothingKey,
        6 => _guideChildSwitcherKey,
        7 => _guideTabSettingsKey,
        _ => null,
      };

  /// スポットライトでくり抜く矩形（画面座標）。対象が見つからなければ null。
  Rect? _guideSpotlightRect(int step) {
    final ctx = _guideTargetKey(step)?.currentContext;
    final box = ctx?.findRenderObject() as RenderBox?;
    if (box == null || !box.attached || !box.hasSize) return null;
    final topLeft = box.localToGlobal(Offset.zero);
    return (topLeft & box.size).inflate(6);
  }

  /// ガイド各ステップの内容。
  /// [arrowX] は矢印の横位置（-1〜1 の Alignment 座標、null なら矢印なし）。
  /// [arrowTop] が true なら画面上部（ヘッダー）を指す上向き矢印にする。
  static const List<({String title, String body, double? arrowX, bool arrowTop})>
      _guideSteps = [
    (
      title: 'まずは記録してみましょう',
      body: '中央の＋ボタンから、その日の身長・体重を記録できます。\n'
          'お子様の設定で出生時の身長・体重を入力した場合は、最初の記録がすでに登録されています。',
      arrowX: 0.0,
      arrowTop: false,
    ),
    (
      title: '成長曲線グラフ',
      body: '記録はこのグラフに●で表示され、標準的な成長曲線と比べられます。\n'
          '●をタップすると、その日の詳細が確認できます。',
      arrowX: null,
      arrowTop: false,
    ),
    (
      title: 'SDスコアグラフ',
      body: 'この右上のボタンで「成長曲線」と「SDスコア」のグラフを切り替えられます。\n'
          'SDスコアは同じ月齢の平均と比べた位置を表す数値で、0が平均です。'
          '「自分のカーブに沿って伸びているか」を見るのに便利です。',
      arrowX: 0.86,
      arrowTop: true,
    ),
    (
      title: '画像保存と受診レポート',
      body: 'この左上の「画像保存」から、成長曲線やサイズガイドを'
          '共有しやすい正方形の画像で保存・シェアできます（Pro版）。'
          'プレビューを見ながら背景カラーや名前の表示も選べます。\n'
          '健診や小児科の受診時にそのまま先生に見せられる'
          '受診レポート（PDF）の出力もここからできます。',
      arrowX: -0.86,
      arrowTop: true,
    ),
    (
      title: '記録の一覧・編集',
      body: '「履歴」タブでは、これまでの記録の確認・編集ができます。\n'
          '右上の「成長ペース」で直近の伸びのまとめ、左上の「思い出」で'
          'お誕生日ごとの写真アルバムも見られます。',
      arrowX: -0.37,
      arrowTop: false,
    ),
    (
      title: 'サイズ予報（洋服・靴・おむつ）',
      body: '「サイズ予報」タブでは、いまの身長から季節ごとの洋服サイズの目安がわかります。\n'
          '「靴ガイド」に切り替えると、足長の実測から靴の買い替え時期を予測できます。'
          'お子様の設定で「おむつガイド」をONにすると、おむつのサイズ目安も見られます。',
      arrowX: 0.37,
      arrowTop: false,
    ),
    (
      title: 'お子様の登録・切り替え',
      body: 'この上部中央の名前をタップすると、お子様の切り替えや追加ができます'
          '（最大6名まで）。きょうだいの記録もこれ1つで管理できます。',
      arrowX: 0.0,
      arrowTop: true,
    ),
    (
      title: '困ったときは',
      body: '「設定」タブに、Q&A・用語解説、このチュートリアルの再生、'
          'データのバックアップ、データの根拠・免責事項があります。'
          'いつでも見返せます。',
      arrowX: 0.75,
      arrowTop: false,
    ),
  ];

  // 初回フレームから「最終UIと完全に同一の構造」を同期的に構築するため、
  // 子供リストはデモ値で同期初期化しておく（ローディング用の別ツリーを挟まない）。
  // 永続データがあれば _loadInitialData が読込後に「データだけ」差し替える。
  // これにより初回起動時のツリー構造スワップ（ヘッダー/bottomNav/FAB の後付けに
  // よるレイアウトのガタつき）が一切発生しなくなる。
  List<ChildProfile> _children = _demoChildren();

  ChildProfile get _selectedChild => _children[_selectedChildIndex];

  static List<ChildProfile> _demoChildren() => [
    ChildProfile(
      id: 'child_1',

      name: '怜久',

      birthDate: DateTime(2022, 8, 15),

      gender: Gender.male,

      iconIndex: 0,

      themeColor: const Color(0xFF7FA6D6),

      growthRecords: [
        GrowthRecord(
          id: 'child1_rec1',
          date: DateTime(2024, 8, 15),
          heightCm: 82.5,
          weightKg: 10.8,
        ),
        GrowthRecord(
          id: 'child1_rec2',
          date: DateTime(2025, 8, 15),
          heightCm: 88.2,
          weightKg: 12.1,
        ),
        GrowthRecord(
          id: 'child1_rec3',
          date: DateTime(2026, 3, 1),
          heightCm: 91.0,
          weightKg: 12.8,
        ),
      ],
    ),

    ChildProfile(
      id: 'child_2',

      name: 'さくら',

      birthDate: DateTime(2025, 1, 10),

      gender: Gender.female,

      iconIndex: 2,

      themeColor: const Color(0xFFDDA0AA),

      growthRecords: [
        GrowthRecord(
          id: 'child2_rec1',
          date: DateTime(2025, 7, 10),
          heightCm: 68.0,
          weightKg: 8.2,
        ),
        GrowthRecord(
          id: 'child2_rec2',
          date: DateTime(2026, 1, 10),
          heightCm: 72.5,
          weightKg: 9.0,
        ),
      ],
    ),
  ];

  @override
  void initState() {
    super.initState();

    _loadInitialData();
    // Pro 版の有効状態（広告非表示・自動バックアップの分岐で参照）。
    ProStatus.load();
    // 書き出し時に名前を伏せる設定（PDF・サイズガイド画像で参照）。
    ExportPrivacy.load();
  }

  Future<void> _loadInitialData() async {
    var loaded = await _repository.loadChildren();
    final withoutScreenshotChild = [
      for (final child in loaded)
        if (child.id != 'screenshot_child') child,
    ];
    if (withoutScreenshotChild.length != loaded.length) {
      await _repository.saveChildren(withoutScreenshotChild);
      loaded = withoutScreenshotChild;
    }

    if (!mounted) return;

    // 永続データが無い初回起動：表示中のデモをそのまま永続化する。
    // 画面はすでにデモを描画済みなので、ツリー構造・データとも変化しない。
    if (loaded.isEmpty) {
      await _persistChildren();
      return;
    }

    // 永続データがある場合は「データだけ」差し替える（フレーム構造は不変）。
    setState(() {
      _children = loaded;
      _selectedChildIndex = _selectedChildIndex.clamp(0, loaded.length - 1);
    });

    appThemeNotifier.value = createChildTheme(_selectedChild.themeColor);

    // 誕生月なら起動時にお祝いを表示する（初回ガイド表示中は出さない）。
    WidgetsBinding.instance.addPostFrameCallback((_) {
      _maybeCelebrateBirthday();
    });
  }

  void _selectChild(int index) {
    setState(() => _selectedChildIndex = index);

    appThemeNotifier.value = createChildTheme(_children[index].themeColor);

    _maybeCelebrateBirthday();
  }

  /// 選択中のお子様が「お祝い対象の誕生月」なら今年の年齢を返す。
  /// 対象外（誕生月でない・表示オフ・0歳）は null。
  int? get _birthdayMonthAge {
    final child = _selectedChild;
    if (!child.birthdayCelebrationEnabled) return null;
    final now = DateTime.now();
    if (now.month != child.birthDate.month) return null;
    final age = now.year - child.birthDate.year;
    return age < 1 ? null : age;
  }

  /// 履歴タブの「思い出」から、選択中のお子様のお誕生日アルバムを開く。
  /// その子の文脈で開くので、テーマ色はその子の色のまま表示する。
  void _openBirthdayMemories() {
    final index = _selectedChildIndex;
    Navigator.of(context).push(
      MaterialPageRoute<void>(
        builder: (_) => BirthdayMemoriesScreen(
          children: [_children[index]],
          onUpdateChild: (_, updated) => _updateChild(index, updated),
        ),
      ),
    );
  }

  /// 誕生月バナーなどから、お祝いダイアログを手動で開く。
  void _openBirthdayCelebration(int age) {
    showBirthdayCelebrationDialog(
      context: context,
      child: _selectedChild,
      age: age,
      onUpdateChild: _saveSelectedChild,
    );
  }

  /// 誕生月の間だけグラフタブ上部に出す、お祝い再表示用のスリムなバナー。
  Widget _buildBirthdayBanner(ColorScheme scheme) {
    final age = _birthdayMonthAge!;
    return Center(
      child: ConstrainedBox(
        constraints: const BoxConstraints(maxWidth: kContentMaxWidth),
        child: Padding(
          padding: const EdgeInsets.fromLTRB(16, 0, 16, 6),
          child: Material(
            color: scheme.primary.withValues(alpha: 0.12),
            borderRadius: BorderRadius.circular(12),
            child: InkWell(
              onTap: () => _openBirthdayCelebration(age),
              borderRadius: BorderRadius.circular(12),
              child: Padding(
                padding:
                    const EdgeInsets.symmetric(horizontal: 12, vertical: 7),
                child: Row(
                  children: [
                    const Text('🎂', style: TextStyle(fontSize: 15)),
                    const SizedBox(width: 8),
                    Expanded(
                      child: Text(
                        '${_selectedChild.displayName} $age歳のお誕生日月です',
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        style: TextStyle(
                          fontSize: 12.5,
                          fontWeight: FontWeight.w700,
                          color: Color.lerp(scheme.primary, Colors.black, 0.3),
                        ),
                      ),
                    ),
                    Text(
                      'お祝いを見る',
                      style: TextStyle(
                        fontSize: 11.5,
                        fontWeight: FontWeight.w600,
                        color: Color.lerp(scheme.primary, Colors.black, 0.3),
                      ),
                    ),
                    Icon(
                      Icons.chevron_right_rounded,
                      size: 18,
                      color: Color.lerp(scheme.primary, Colors.black, 0.3),
                    ),
                  ],
                ),
              ),
            ),
          ),
        ),
      ),
    );
  }

  /// 選択中のお子様が誕生月なら、お祝いダイアログを表示する。
  /// 自動表示は同じ誕生日（年齢）につき1回だけ（誕生月の間はグラフ上部の
  /// バナーからいつでも開き直せる）。ガイド表示中はスキップし、
  /// ガイド終了時に改めて呼ばれる。
  Future<void> _maybeCelebrateBirthday() async {
    if (!mounted || _guideStep != null) return;
    final child = _selectedChild;
    final age = _birthdayMonthAge;
    if (age == null) return;
    if (child.celebratedBirthdayAges.contains(age)) return;

    // 先に「表示済み」を永続化してから出す（タブ切替等での多重表示を防ぐ）。
    await _saveSelectedChild(child.copyWith(
      celebratedBirthdayAges: [...child.celebratedBirthdayAges, age],
    ));
    if (!mounted) return;
    await showBirthdayCelebrationDialog(
      context: context,
      child: _selectedChild,
      age: age,
      onUpdateChild: _saveSelectedChild,
    );
  }

  Future<void> _updateChild(int index, ChildProfile updated) async {
    setState(() {
      _children = [
        for (int i = 0; i < _children.length; i++)
          i == index ? updated : _children[i],
      ];
    });

    if (index == _selectedChildIndex) {
      appThemeNotifier.value = createChildTheme(updated.themeColor);
    }

    await _persistChildren();
  }

  /// ローカル保存＋（Pro・サインイン時のみ）クラウド自動バックアップ。
  Future<void> _persistChildren() async {
    await _repository.saveChildren(_children);
    CloudBackup.instance.onDataChanged(_children);
  }

  Future<void> _addChild(ChildProfile child) async {
    setState(() {
      _children = [..._children, child];

      _selectedChildIndex = _children.length - 1;
    });

    appThemeNotifier.value = createChildTheme(child.themeColor);

    await _persistChildren();

    // お子様が1人目のときだけ使い方ガイドを自動表示する（2人目以降は出さない）。
    if (_children.length == 1) {
      await _maybeStartGuide();
    }
  }

  /// お子様を1名削除する（プロフィール編集シートの削除ボタンから）。
  ///
  /// アプリ全体が「常に1名以上」を前提に作られているため、最後の1名は
  /// 削除できない（呼び出し側のUIでもブロックしている）。
  Future<void> _removeChild(int index) async {
    if (_children.length <= 1) return;
    setState(() {
      _children = [
        for (int i = 0; i < _children.length; i++)
          if (i != index) _children[i],
      ];
      // 選択中の子を維持する：選択より前が消えたら位置を1つ詰め、
      // 選択中の子自身が消えたら同じ位置（末尾なら最後）の子へ移る。
      if (index < _selectedChildIndex) {
        _selectedChildIndex -= 1;
      } else if (_selectedChildIndex >= _children.length) {
        _selectedChildIndex = _children.length - 1;
      }
    });
    appThemeNotifier.value = createChildTheme(_selectedChild.themeColor);
    await _persistChildren();
  }

  /// お子様の表示順を入れ替える（プロフィール一覧のドラッグ並び替えから）。
  /// 選択中の子は ID で追跡し、並び替え後も同じ子が選ばれたままにする。
  Future<void> _reorderChildren(int oldIndex, int newIndex) async {
    final selectedId = _selectedChild.id;
    setState(() {
      final list = [..._children];
      list.insert(newIndex, list.removeAt(oldIndex));
      _children = list;
      _selectedChildIndex = _children.indexWhere((c) => c.id == selectedId);
    });
    await _persistChildren();
  }

  /// 1人目の登録直後のみ、未完了なら使い方ガイドを開始する（グラフタブへ移動）。
  Future<void> _maybeStartGuide() async {
    final prefs = await SharedPreferences.getInstance();
    if (prefs.getBool(_kGuideDoneKey) ?? false) return;
    if (!mounted) return;
    setState(() {
      _tabIndex = 0;
      _guideStep = 0;
    });
  }

  /// ガイドを閉じて「表示済み」を永続化する（完了・スキップ共通）。
  Future<void> _finishGuide() async {
    setState(() => _guideStep = null);
    final prefs = await SharedPreferences.getInstance();
    await prefs.setBool(_kGuideDoneKey, true);
    // ガイド中に保留していたお祝いがあればここで出す。
    await _maybeCelebrateBirthday();
  }

  /// 設定の「チュートリアルを見る」から使い方ガイドを再生する。
  /// ガイドはグラフ画面を前提に説明するため、グラフタブへ移動してから出す。
  void _replayGuide() {
    setState(() {
      _tabIndex = 0;
      _guideStep = 0;
    });
  }

  void _nextGuideStep() {
    final step = _guideStep;
    if (step == null) return;
    if (step >= _guideSteps.length - 1) {
      _finishGuide();
    } else {
      setState(() => _guideStep = step + 1);
    }
  }

  Future<void> _saveSelectedChild(ChildProfile updated) async {
    await _updateChild(_selectedChildIndex, updated);
  }

  /// バックアップの読み込みで全お子様データを置き換える（設定画面から）。
  Future<void> _restoreChildren(List<ChildProfile> restored) async {
    setState(() {
      _children = restored;
      _selectedChildIndex = 0;
    });
    appThemeNotifier.value = createChildTheme(restored.first.themeColor);
    await _persistChildren();
  }

  void _openAddRecordSheet() {
    showGrowthRecordSheet(
      context: context,

      child: _selectedChild,

      onSave: _saveSelectedChild,
    );
  }

  void _openAddChildSheet() {
    if (_children.length >= 6) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('お子様は最大6名まで登録できます'),

          behavior: SnackBarBehavior.floating,
        ),
      );

      return;
    }

    showChildProfileModal(context, children: _children, onAddChild: _addChild);
  }

  /// 設定画面を開く（戻り先のコンテンツタブを記憶しておく）。
  void _openSettings() {
    setState(() {
      _lastContentTabIndex = _tabIndex == _settingsTabIndex
          ? _lastContentTabIndex
          : _tabIndex;
      _tabIndex = _settingsTabIndex;
    });
  }

  /// 設定画面から元のコンテンツタブ（グラフ/履歴）へ戻る。
  void _closeSettings() {
    setState(() => _tabIndex = _lastContentTabIndex);
  }

  void _showSnack(String message) {
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(content: Text(message), behavior: SnackBarBehavior.floating),
    );
  }

  /// ファイル名用の日時スタンプ（例: 20260702_2130）。
  static String _dateStamp() {
    final now = DateTime.now();
    return '${now.year}${now.month.toString().padLeft(2, '0')}${now.day.toString().padLeft(2, '0')}'
        '_${now.hour.toString().padLeft(2, '0')}${now.minute.toString().padLeft(2, '0')}';
  }

  /// 書き出しに使う表示名（プライバシー設定ONなら「第一子」など）。
  String get _exportDisplayName =>
      ExportPrivacy.displayNameFor(_selectedChild, _children);

  /// エクスポートファイル名（例: 成長記録_たろう_20260702_2130）。
  /// ファイル名にも名前が入るため、伏せ字設定はここにも反映する。
  String _exportBaseName() => '成長記録_${_exportDisplayName}_${_dateStamp()}';

  /// 書き出しファイル名（例: 成長曲線_たろう_20260702_2130）。
  /// 伏せ字設定はファイル名にも反映する。
  String _exportImageFileName(SizeExportItem item) {
    final label = switch (item) {
      SizeExportItem.growthChart ||
      SizeExportItem.sdChart => sizeExportItemLabel(item),
      _ => '${sizeExportItemLabel(item)}サイズガイド',
    };
    return '${label}_${_exportDisplayName}_${_dateStamp()}';
  }

  /// ヘッダー左上の「画像保存」から開く保存・シェア画面。
  ///
  /// 完成品のプレビューを見ながら、種類の切り替え（スワイプ／チップ）、
  /// 背景カラー、「名前を表示」のON/OFFをその場で変更して、保存（1枚／全部）
  /// やシェアができる。画像はPro版の機能（プレビューは無料でも見られる）。
  /// 受診レポート（PDF）の入り口もこの画面に置く（こちらは無料版でも使える）。
  Future<void> _openExportPreview() async {
    final items = <SizeExportItem>[
      SizeExportItem.growthChart,
      SizeExportItem.sdChart,
      if (_selectedChild.diaperGuideEnabled) SizeExportItem.diaper,
      SizeExportItem.clothing,
      SizeExportItem.shoe,
    ];
    // 見ていたページに対応する項目を最初に表示する。
    final current = switch (_tabIndex) {
      0 =>
        _graphChartType.value == 0
            ? SizeExportItem.growthChart
            : SizeExportItem.sdChart,
      2 => exportItemForGuideTab(_guideMode.value),
      _ => SizeExportItem.growthChart,
    };
    await Navigator.of(context).push(
      MaterialPageRoute(
        builder: (_) => ExportPreviewScreen(
          child: _selectedChild,
          items: items,
          initialItem: items.contains(current) ? current : items.first,
          // ファイル名には「名前を伏せる」設定を反映（画像内の名前表示は
          // プレビュー画面のトグルで都度選べる）。
          fileNameFor: _exportImageFileName,
          onExportPdf: _exportPdf,
        ),
      ),
    );
  }

  /// 成長記録レポート PDF を生成して端末に保存する（Web ではダウンロード）。
  /// ※無料版では将来ここで出力前に広告を挟む予定。
  Future<void> _exportPdf() async {
    try {
      final bytes = await GrowthPdf.build(
        child: _selectedChild,
        displayName: _exportDisplayName,
      );
      if (!mounted) return;
      final saved = await saveBytesToDevice(
        name: _exportBaseName(),
        bytes: bytes,
        fileExtension: 'pdf',
        mimeType: MimeType.pdf,
      );
      // キャンセル時（Androidの保存先選択ダイアログを閉じた等）は何も出さない。
      if (mounted && saved) _showSnack('PDFを保存しました');
    } on Exception catch (e) {
      // 原因（フォント読込失敗など）を調査できるようログには残す。
      debugPrint('PDF export failed: $e');
      if (mounted) _showSnack('PDFの作成に失敗しました');
    }
  }

  /// 子供のアバター（写真があれば写真、無ければアイコン）。
  Widget _childAvatar(ChildProfile child, {required double radius}) {
    if (child.photoBytes != null) {
      return CircleAvatar(
        radius: radius,
        backgroundImage: MemoryImage(child.photoBytes!),
      );
    }
    final fg = Color.lerp(child.themeColor, Colors.black, 0.55)!;
    return CircleAvatar(
      radius: radius,
      backgroundColor: child.themeColor.withValues(alpha: 0.25),
      child: Icon(
        kChildIconOptions[child.iconIndex.clamp(
          0,
          kChildIconOptions.length - 1,
        )],
        size: radius * 1.1,
        color: fg,
      ),
    );
  }

  /// 中央ヘッダーの子供切り替えドロップダウン。
  /// 選択中の子（アバター＋名前＋▼）を表示し、タップで一覧＋「追加」を出す。
  /// 切り替えロジックは従来のタブと同じ [_selectChild] / [_openAddChildSheet]。
  Widget _buildChildSwitcher(ColorScheme scheme) {
    final selected = _selectedChild;
    final selectedFg = Color.lerp(selected.themeColor, Colors.black, 0.6)!;

    return PopupMenuButton<int>(
      tooltip: 'お子様を切り替え',
      offset: const Offset(0, 46),
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
      // -1 は「新しい子供を追加」を表す特別値。
      onSelected: (value) {
        if (value == -1) {
          _openAddChildSheet();
        } else {
          _selectChild(value);
        }
      },
      itemBuilder: (context) => [
        for (int i = 0; i < _children.length; i++)
          PopupMenuItem<int>(
            value: i,
            child: Row(
              children: [
                _childAvatar(_children[i], radius: 13),
                const SizedBox(width: 10),
                Expanded(
                  child: Text(
                    _children[i].displayName,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: TextStyle(
                      fontWeight: i == _selectedChildIndex
                          ? FontWeight.w700
                          : FontWeight.w500,
                    ),
                  ),
                ),
                if (i == _selectedChildIndex)
                  Icon(Icons.check_rounded, size: 18, color: scheme.primary),
              ],
            ),
          ),
        const PopupMenuDivider(),
        PopupMenuItem<int>(
          value: -1,
          child: Row(
            children: [
              Icon(Icons.add_rounded, size: 20, color: scheme.primary),
              const SizedBox(width: 10),
              Text(
                '新しい子供を追加',
                style: TextStyle(
                  color: scheme.primary,
                  fontWeight: FontWeight.w600,
                ),
              ),
            ],
          ),
        ),
      ],
      child: Container(
        padding: const EdgeInsets.fromLTRB(6, 4, 6, 4),
        constraints: const BoxConstraints(maxWidth: 220),
        decoration: BoxDecoration(
          color: Colors.white.withValues(alpha: 0.55),
          borderRadius: BorderRadius.circular(22),
          border: Border.all(
            color: selected.themeColor.withValues(alpha: 0.30),
          ),
        ),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            _childAvatar(selected, radius: 13),
            const SizedBox(width: 8),
            Flexible(
              child: Text(
                selected.displayName,
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
                style: TextStyle(
                  fontSize: 15,
                  fontWeight: FontWeight.w700,
                  color: selectedFg,
                ),
              ),
            ),
            Icon(Icons.arrow_drop_down, color: selectedFg),
          ],
        ),
      ),
    );
  }

  /// 履歴タブから成長ペースサマリーを開く（旧・履歴画面 AppBar 右上）。
  Future<void> _showHistoryGrowthPace() async {
    final result = await showGrowthSummarySheet(
      context: context,
      child: _selectedChild,
    );
    _historyScreenKey.currentState?.handleSummaryDialogResult(result);
  }

  /// ヘッダー右上用の「アイコン＋小さな文字」ボタン。
  Widget _headerLabeledAction({
    required IconData icon,
    required String label,
    required String tooltip,
    required VoidCallback onPressed,
    required ColorScheme scheme,
  }) {
    final fg = scheme.onSurfaceVariant;
    return Tooltip(
      message: tooltip,
      child: Material(
        color: Colors.transparent,
        child: InkWell(
          onTap: onPressed,
          borderRadius: BorderRadius.circular(10),
          child: Padding(
            padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                Icon(icon, size: 20, color: fg),
                const SizedBox(height: 2),
                Text(
                  label,
                  maxLines: 1,
                  softWrap: false,
                  style: TextStyle(
                    fontSize: 9,
                    fontWeight: FontWeight.w600,
                    height: 1.0,
                    color: fg,
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }

  /// グラフタブ右上の「成長曲線 / SDスコア」切り替え。
  /// タップで切り替わる相手（表示先）のアイコンと名前を出す。
  Widget _buildChartTypeHeaderToggle(ColorScheme scheme) {
    return ValueListenableBuilder<int>(
      valueListenable: _graphChartType,
      builder: (context, page, _) {
        final showingGrowth = page == 0;
        return _headerLabeledAction(
          icon: showingGrowth
              ? Icons.stacked_line_chart_rounded
              : Icons.show_chart_rounded,
          label: showingGrowth ? 'SDスコア' : '成長曲線',
          tooltip: showingGrowth
              ? 'SDスコアグラフに切り替え'
              : '成長曲線グラフに切り替え',
          onPressed: () => _graphChartType.value = showingGrowth ? 1 : 0,
          scheme: scheme,
        );
      },
    );
  }

  /// 保存・書き出しの統一の入り口（グラフ／サイズ予報タブの左上）。
  /// 押すとプレビュー画面が開き、画像の保存・シェア（Pro版）と
  /// 受診レポートPDFの出力ができる。
  Widget _buildImageSaveHeaderButton(ColorScheme scheme) {
    return _headerLabeledAction(
      icon: Icons.image_outlined,
      label: '画像保存',
      tooltip:
          '成長曲線・SDスコア・サイズガイドを正方形の画像で保存・シェア（Pro版）。'
          '受診レポート（PDF）の出力もこちらから',
      onPressed: _openExportPreview,
      scheme: scheme,
    );
  }

  /// 通常ヘッダー：左右とも「アイコン＋小さな文字」で統一。
  /// グラフ／サイズ予報：左=画像保存（保存ダイアログ。PDF出力もこの中）、
  /// 右=グラフ種類切り替え。保存した画像は LINE・Instagram 等の
  /// 別アプリから送って共有する想定。
  /// 履歴：左=思い出、右=成長ペース。
  Widget _buildMainHeader(ColorScheme scheme) {
    final Widget? leftAction = switch (_tabIndex) {
      0 => KeyedSubtree(
        // チュートリアルのスポットライト位置取得用。
        key: _guideHeaderLeftKey,
        child: _buildImageSaveHeaderButton(scheme),
      ),
      // 履歴＝その子の時系列、という文脈に合わせて思い出アルバムへの入り口を置く。
      1 => _headerLabeledAction(
        icon: Icons.cake_outlined,
        label: '思い出',
        tooltip: 'お誕生日の思い出（写真・サイズ・メモ）',
        onPressed: _openBirthdayMemories,
        scheme: scheme,
      ),
      2 => _buildImageSaveHeaderButton(scheme),
      _ => null,
    };
    final Widget? rightAction = switch (_tabIndex) {
      0 => KeyedSubtree(
        key: _guideHeaderRightKey,
        child: _buildChartTypeHeaderToggle(scheme),
      ),
      1 => _headerLabeledAction(
        icon: Icons.speed_rounded,
        label: '成長ペース',
        tooltip: '成長ペースを見る',
        onPressed: _showHistoryGrowthPace,
        scheme: scheme,
      ),
      _ => null,
    };

    // 左右を同じ固定幅にして、中央の子供切り替えを常にセンターに保つ。
    const sideWidth = 76.0;
    return Row(
      children: [
        SizedBox(
          width: sideWidth,
          child: Align(
            alignment: Alignment.centerLeft,
            child: leftAction ?? const SizedBox.shrink(),
          ),
        ),
        Expanded(
          child: Center(
            child: KeyedSubtree(
              key: _guideChildSwitcherKey,
              child: _buildChildSwitcher(scheme),
            ),
          ),
        ),
        SizedBox(
          width: sideWidth,
          child: Align(
            alignment: Alignment.centerRight,
            child: rightAction ?? const SizedBox.shrink(),
          ),
        ),
      ],
    );
  }

  /// 設定画面用ヘッダー：左=戻る / 中央=「設定」のみ（出力/選択/歯車は出さない）。
  /// 子のテーマ色は使わずニュートラルな配色にする。
  Widget _buildSettingsHeader(ColorScheme scheme) {
    const fg = Color(0xFF333333);
    return Row(
      children: [
        IconButton(
          onPressed: _closeSettings,
          tooltip: '戻る',
          visualDensity: VisualDensity.compact,
          iconSize: 22,
          icon: const Icon(Icons.arrow_back_rounded, color: fg),
        ),
        const Expanded(
          child: Center(
            child: Text(
              '設定',
              style: TextStyle(
                fontSize: 17,
                fontWeight: FontWeight.w700,
                color: fg,
              ),
            ),
          ),
        ),
        // 左の戻るボタンと釣り合う右側の余白（タイトルを中央に保つ）。
        const SizedBox(width: 48),
      ],
    );
  }

  /// 設定画面用のニュートラルなテーマ（特定の子のテーマ色を切り離す）。
  ThemeData _neutralTheme() {
    final scheme =
        ColorScheme.fromSeed(
          seedColor: const Color(0xFF8A8F98),
          brightness: Brightness.light,
        ).copyWith(
          surface: _settingsBackground,
          surfaceContainerLowest: Colors.white,
        );
    return ThemeData(
      useMaterial3: true,
      fontFamily: 'ZenMaruGothic',
      colorScheme: scheme,
      scaffoldBackgroundColor: _settingsBackground,
    );
  }

  @override
  Widget build(BuildContext context) {
    // 子供リストは同期初期化済みのため、初回フレームから最終UIと同一構造を構築する。
    // （ローディング用の別ツリーは持たない＝起動時の構造スワップを排除。）
    final scheme = Theme.of(context).colorScheme;
    // 選択中の子のテーマ色をうっすら背景に敷き、上部の子供切り替えタブと
    // 連続した見た目にする（全タブ共通）。
    final screenBg = _selectedChild.themeColor.withValues(
      alpha: _screenBackgroundAlpha,
    );
    // Scaffold の背景は必ず不透明にする。半透明のまま渡すと、FAB ノッチの
    // 切り欠きなど body が覆わない隙間でウィンドウの黒が透けてしまう
    // （＋ボタンの周りが黒く見える不具合の原因）。
    final opaqueScreenBg = Color.alphaBlend(screenBg, Colors.white);
    // 大画面では下部メニューを比例拡大する（最大1.3倍）。
    final uiScale = uiScaleForWidth(MediaQuery.sizeOf(context).width);

    final scaffold = Scaffold(
      // 設定画面では特定の子のテーマ色を使わず、ニュートラルな背景にする。
      backgroundColor: _isSettings ? _settingsBackground : opaqueScreenBg,
      // スクショ・共有用に body 全体を RepaintBoundary で包む。
      // Scaffold の背景色は boundary の外なので、白＋テーマ淡色を内側でも
      // 重ねて、書き出した画像が透過にならないようにする。
      body: RepaintBoundary(
        key: ScreenCapture.boundaryKey,
        child: ColoredBox(
          color: Colors.white,
          child: ColoredBox(
            color: _isSettings ? _settingsBackground : screenBg,
            child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          // ── ヘッダー（縦1行・スリム） ──
          // 通常：左=エクスポート / 中央=子供ドロップダウン / 右=余白（設定はボトムバー）
          // 設定中：左=戻る / 中央=「設定」タイトルのみ（出力/選択/歯車は非表示）
          SafeArea(
            bottom: false,
            child: Padding(
              // 上に多めの余白を取り、ヘッダーが画面上端に張り付いて
              // 見えないようにする（詰まった印象の解消）。
              padding: const EdgeInsets.fromLTRB(8, 18, 8, 6),
              // 大画面ではヘッダーの操作ボタンがコンテンツ（最大幅 600px）の
              // 端と揃うよう、ヘッダーも同じ幅制限で中央寄せする。
              child: Center(
                child: ConstrainedBox(
                  constraints: const BoxConstraints(maxWidth: kContentMaxWidth),
                  child: _isSettings
                      ? _buildSettingsHeader(scheme)
                      : _buildMainHeader(scheme),
                ),
              ),
            ),
          ),
          // ── 広告バナー（無料版のみ・Android/iOSのみ） ──
          // Pro版・Web・読み込み前は AdBanner 側で高さ0になる。
          // 下部だと中央の＋ボタンのすぐ近くになり誤タップを誘う見た目に
          // なるため（ユーザーフィードバック・AdMobポリシー配慮）、
          // 操作ボタンから遠いヘッダー直下に置く。
          const AdBanner(),
          // 誕生月の間だけ、グラフタブ上部に「お祝いを見る」バナーを出す。
          // 自動ポップアップは1回だが、写真の追加・見返しはここから月内いつでも。
          if (!_isSettings && _tabIndex == 0 && _birthdayMonthAge != null)
            _buildBirthdayBanner(scheme),
          Expanded(
            child: IndexedStack(
              index: _tabIndex,
              children: [
                // グラフは textScaler では拡大しない（軸ラベルの位置整合を
                // 崩さないよう、画面側で軸フォント・確保領域を同率拡大する）。
                GrowthHomeScreen(
                  key: ValueKey('graph_${_selectedChild.id}'),
                  child: _selectedChild,
                  chartTypeNotifier: _graphChartType,
                ),
                // 履歴・設定はテキストスケールで全体をひと回り拡大する。
                // 行高は文字サイズに追従するため、リストが自然に大きくなる。
                _scaledTextSubtree(
                  uiScale,
                  RecordHistoryScreen(
                    key: _historyScreenKey,
                    child: _selectedChild,
                    onUpdateChild: _saveSelectedChild,
                  ),
                ),
                // 洋服ガイドは FittedBox の比例拡大で対応済み。
                ClothingGuideScreen(
                  key: ValueKey('clothing_${_selectedChild.id}'),
                  child: _selectedChild,
                  onUpdateChild: _saveSelectedChild,
                  modeNotifier: _guideMode,
                ),
                // 設定画面は子のテーマ色を切り離し、ニュートラルなテーマで描画する。
                _scaledTextSubtree(
                  uiScale,
                  Theme(
                    data: _neutralTheme(),
                    child: SettingsScreen(
                      children: _children,
                      onUpdateChild: _updateChild,
                      onAddChild: _addChild,
                      onDeleteChild: _removeChild,
                      onReorderChild: _reorderChildren,
                      onReplayTutorial: _replayGuide,
                      onRestoreChildren: _restoreChildren,
                    ),
                  ),
                ),
              ],
            ),
          ),
        ],
            ),
          ),
        ),
      ),
      // メインアクション「記録を追加」を中央下部に配置（設定画面では非表示）。
      floatingActionButton: _isSettings
          ? null
          : FloatingActionButton(
              key: _guideFabKey,
              onPressed: _openAddRecordSheet,
              elevation: 5,
              shape: const CircleBorder(),
              backgroundColor: scheme.primary,
              foregroundColor: Colors.black87,
              tooltip: '記録を追加',
              child: const Icon(Icons.add_rounded, size: 32),
            ),
      // centerDocked を基準に FAB を少し下へ沈めてボトムバーに食い込ませる。
      // ノッチは FAB の実ジオメトリから計算されるため一緒に追従する。
      floatingActionButtonLocation: const _CenterDockedSunkenFabLocation(10),
      bottomNavigationBar: BottomAppBar(
        // 大画面では下部メニューも比例拡大する（uiScale は最大1.3倍）。
        height: 64 * uiScale,
        padding: EdgeInsets.zero,
        // 設定画面では FAB を出さないためノッチも切らない。
        shape: _isSettings ? null : const CircularNotchedRectangle(),
        notchMargin: 8,
        elevation: 10,
        color: scheme.surface,
        child: Row(
          children: [
            // 左：グラフ・履歴（FAB を挟んで右に洋服ガイド・設定）
            Expanded(
              child: Row(
                children: [
                  Expanded(
                    child: Center(
                      child: _bottomNavItem(
                        index: 0,
                        icon: Icons.show_chart_outlined,
                        selectedIcon: Icons.show_chart,
                        label: 'グラフ',
                        scheme: scheme,
                        scale: uiScale,
                      ),
                    ),
                  ),
                  Expanded(
                    child: Center(
                      child: KeyedSubtree(
                        key: _guideTabHistoryKey,
                        child: _bottomNavItem(
                          index: 1,
                          icon: Icons.history_outlined,
                          selectedIcon: Icons.history,
                          label: '履歴',
                          scheme: scheme,
                          scale: uiScale,
                        ),
                      ),
                    ),
                  ),
                ],
              ),
            ),
            // 中央：FAB のためのノッチ用スペース。沈み込んだ＋ボタンの
            // すぐ下に「何の入力か」を示すラベルを置く（靴ガイドなどで
            // ＋＝身長・体重入力だと分かりにくい、というフィードバック対応）。
            // ラベルは両隣のタブ（グラフ・履歴など）と同じ構成
            // （アイコン枠ぶんの空き＋同じ書式の文字）で組み、
            // 文字の大きさ・縦位置がタブの文字とそろうようにする。
            SizedBox(
              width: 68 * uiScale,
              height: double.infinity,
              child: _isSettings
                  ? null
                  : Center(
                      child: Column(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          // タブのアイコンピル（縦padding 2×2＋アイコン）と
                          // 同じ高さの空き。この位置にはFABが重なっている。
                          SizedBox(height: 24 * uiScale + 4),
                          const SizedBox(height: 2),
                          Text(
                            '身長・体重',
                            maxLines: 1,
                            softWrap: false,
                            style: TextStyle(
                              fontSize: 10 * uiScale,
                              fontWeight: FontWeight.w500,
                              color: scheme.onSurfaceVariant,
                            ),
                          ),
                        ],
                      ),
                    ),
            ),
            // 右：洋服ガイド・設定
            Expanded(
              child: Row(
                children: [
                  Expanded(
                    child: Center(
                      child: KeyedSubtree(
                        key: _guideTabClothingKey,
                        child: _bottomNavItem(
                          index: 2,
                          label: 'サイズ予報',
                          scheme: scheme,
                          scale: uiScale,
                          buildIcon: (selected, color) => PhosphorIcon(
                            selected
                                ? PhosphorIconsFill.shirtFolded
                                : PhosphorIconsRegular.shirtFolded,
                            color: color,
                            size: 24 * uiScale,
                          ),
                        ),
                      ),
                    ),
                  ),
                  Expanded(
                    child: Center(
                      child: KeyedSubtree(
                        key: _guideTabSettingsKey,
                        child: _bottomNavItem(
                          index: _settingsTabIndex,
                          icon: Icons.settings_outlined,
                          selectedIcon: Icons.settings,
                          label: '設定',
                          scheme: scheme,
                          scale: uiScale,
                        ),
                      ),
                    ),
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );

    // 使い方ガイド表示中は、FAB・ボトムバーも含めた全面にオーバーレイを重ねる。
    if (_guideStep == null) return scaffold;
    return Stack(
      children: [scaffold, _buildGuideOverlay(scheme)],
    );
  }

  /// 初回の使い方ガイドのオーバーレイ。
  /// 暗いスクリム＋説明カード＋対象（＋ボタン／タブ）を指す矢印で構成する。
  /// スクリムのタップでも次のステップへ進める。
  Widget _buildGuideOverlay(ColorScheme scheme) {
    final step = _guideStep!;
    final s = _guideSteps[step];
    final isLast = step == _guideSteps.length - 1;
    final arrowX = s.arrowX;
    // ＋ボタン（step 0）はボトムバーに食い込んで少し高い位置にあるため、
    // 矢印の下に確保する余白をタブ行より広めに取る。
    final bottomGap = step == 0 ? 84.0 : 70.0;

    final card = Container(
      margin: const EdgeInsets.symmetric(horizontal: 24),
      padding: const EdgeInsets.fromLTRB(20, 18, 20, 10),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(20),
      ),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Text(
            s.title,
            style: const TextStyle(
              fontSize: 17,
              fontWeight: FontWeight.w700,
              color: Color(0xFF333333),
            ),
          ),
          const SizedBox(height: 8),
          Text(
            s.body,
            style: const TextStyle(
              fontSize: 14,
              height: 1.55,
              color: Color(0xFF555555),
            ),
          ),
          const SizedBox(height: 12),
          Row(
            children: [
              // 進捗ドット（現在のステップだけ横長にする）。
              // ステップ数が多く狭い端末で溢れないよう、必要なら縮小する。
              Expanded(
                child: FittedBox(
                  fit: BoxFit.scaleDown,
                  alignment: Alignment.centerLeft,
                  child: Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      for (int i = 0; i < _guideSteps.length; i++)
                        Container(
                          margin: const EdgeInsets.only(right: 6),
                          width: i == step ? 18 : 7,
                          height: 7,
                          decoration: BoxDecoration(
                            color: i == step
                                ? scheme.primary
                                : scheme.primary.withValues(alpha: 0.25),
                            borderRadius: BorderRadius.circular(4),
                          ),
                        ),
                    ],
                  ),
                ),
              ),
              TextButton(
                onPressed: _finishGuide,
                child: const Text('スキップ'),
              ),
              const SizedBox(width: 4),
              FilledButton(
                onPressed: _nextGuideStep,
                child: Text(isLast ? 'はじめる' : '次へ'),
              ),
            ],
          ),
        ],
      ),
    );

    final Widget layout;
    if (arrowX == null) {
      layout = Center(child: card);
    } else if (s.arrowTop) {
      // 上向き矢印：ヘッダーのボタン位置を指す。ヘッダーは最大幅
      // kContentMaxWidth で中央寄せされているため、矢印も同じ幅制限内で
      // 揃えると大画面でも実際のボタン位置と一致する。
      layout = Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          // ヘッダー行（高さ約48px）の直下に矢印を置く。
          const SizedBox(height: 52),
          Center(
            child: ConstrainedBox(
              constraints: const BoxConstraints(maxWidth: kContentMaxWidth),
              child: Align(
                alignment: Alignment(arrowX, 0),
                child: const Padding(
                  padding: EdgeInsets.symmetric(horizontal: 16),
                  child: Icon(
                    Icons.arrow_upward_rounded,
                    color: Colors.white,
                    size: 34,
                  ),
                ),
              ),
            ),
          ),
          const SizedBox(height: 6),
          card,
        ],
      );
    } else {
      layout = Column(
        mainAxisAlignment: MainAxisAlignment.end,
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          card,
          const SizedBox(height: 6),
          Align(
            alignment: Alignment(arrowX, 0),
            child: const Icon(
              Icons.arrow_downward_rounded,
              color: Colors.white,
              size: 34,
            ),
          ),
          SizedBox(height: bottomGap),
        ],
      );
    }

    // スポットライト：対象UIの矩形をくり抜いて、そこだけ明るく見せる。
    // 対象が出現アニメーション中（設定画面からの再生直後の FAB など）や
    // レイアウト未確定のこともあるため、毎フレーム位置を確認して、
    // 変化があれば描き直す（安定したら自然に止まる）。
    final hole = _guideSpotlightRect(step);
    if (_guideTargetKey(step) != null) {
      WidgetsBinding.instance.addPostFrameCallback((_) {
        if (!mounted || _guideStep != step) return;
        if (_guideSpotlightRect(step) != hole) setState(() {});
      });
    }

    return Positioned.fill(
      child: GestureDetector(
        behavior: HitTestBehavior.opaque,
        onTap: _nextGuideStep,
        child: Material(
          type: MaterialType.transparency,
          child: Stack(
            fit: StackFit.expand,
            children: [
              CustomPaint(painter: _GuideSpotlightPainter(hole: hole)),
              SafeArea(child: layout),
            ],
          ),
        ),
      ),
    );
  }

  /// 大画面時のみ、サブツリーの textScaler を [scale] 倍に引き上げる。
  /// 等倍時は何もしない（OS のアクセシビリティ文字サイズ設定を上書きしない）。
  Widget _scaledTextSubtree(double scale, Widget child) {
    if (scale <= 1.001) return child;
    return Builder(
      builder: (context) {
        final mq = MediaQuery.of(context);
        return MediaQuery(
          data: mq.copyWith(textScaler: TextScaler.linear(scale)),
          child: child,
        );
      },
    );
  }

  /// ボトムバーのタブ 1 つ分。選択中はテーマ色で強調する。
  ///
  /// くすみパステルのテーマ色は白背景とのコントラストが低い（黄・ラベンダー等で
  /// 2:1 未満）ため、選択中の前景はテーマ色を黒に40%寄せた濃色にし、
  /// 「その子の色」の印象はアイコン背後の淡色ピルで表現する。
  Widget _bottomNavItem({
    required int index,
    IconData? icon,
    IconData? selectedIcon,
    Widget Function(bool selected, Color color)? buildIcon,
    required String label,
    required ColorScheme scheme,
    double scale = 1.0,
  }) {
    final selected = _tabIndex == index;
    final color = selected
        ? Color.lerp(scheme.primary, Colors.black, 0.40)!
        : scheme.onSurfaceVariant;
    return InkWell(
      onTap: () {
        if (index == _settingsTabIndex) {
          _openSettings();
        } else {
          setState(() => _tabIndex = index);
        }
      },
      borderRadius: BorderRadius.circular(16),
      child: Padding(
        padding: EdgeInsets.symmetric(horizontal: 8 * scale, vertical: 4),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            AnimatedContainer(
              duration: const Duration(milliseconds: 180),
              curve: Curves.easeOut,
              padding: EdgeInsets.symmetric(
                horizontal: 12 * scale,
                vertical: 2,
              ),
              decoration: BoxDecoration(
                color: selected
                    ? scheme.primary.withValues(alpha: 0.28)
                    : Colors.transparent,
                borderRadius: BorderRadius.circular(12 * scale),
              ),
              child: buildIcon != null
                  ? buildIcon(selected, color)
                  : Icon(
                      selected ? selectedIcon! : icon!,
                      color: color,
                      size: 24 * scale,
                    ),
            ),
            const SizedBox(height: 2),
            Text(
              label,
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
              style: TextStyle(
                fontSize: 10 * scale,
                color: color,
                fontWeight: selected ? FontWeight.w700 : FontWeight.w500,
              ),
            ),
          ],
        ),
      ),
    );
  }
}

/// 使い方ガイドの暗いスクリム。[hole] の矩形だけをくり抜き、
/// 対象のボタンにスポットライトが当たっているように見せる。
class _GuideSpotlightPainter extends CustomPainter {
  _GuideSpotlightPainter({required this.hole});

  /// くり抜く矩形（画面座標）。null なら全面を暗くする。
  final Rect? hole;

  @override
  void paint(Canvas canvas, Size size) {
    final scrim = Paint()..color = Colors.black.withValues(alpha: 0.55);
    final full = Offset.zero & size;
    final target = hole;
    if (target == null) {
      canvas.drawRect(full, scrim);
      return;
    }
    // 円形に近い対象（FAB）は丸く、横長の対象は角丸長方形でくり抜く。
    final radius = Radius.circular(
      (target.width - target.height).abs() < 12
          ? target.shortestSide / 2
          : 14,
    );
    final rrect = RRect.fromRectAndRadius(target, radius);
    // Path.combine(difference) は Web レンダラーで空パスになることがあるため、
    // evenOdd の塗りルールで「全面＋くり抜き」を1つのパスとして描く。
    final scrimPath = Path()
      ..fillType = PathFillType.evenOdd
      ..addRect(full)
      ..addRRect(rrect);
    canvas.drawPath(scrimPath, scrim);
    // くり抜きの縁を白くふちどりして視線を集める。
    canvas.drawRRect(
      rrect,
      Paint()
        ..style = PaintingStyle.stroke
        ..strokeWidth = 2
        ..color = Colors.white.withValues(alpha: 0.9),
    );
  }

  @override
  bool shouldRepaint(_GuideSpotlightPainter oldDelegate) =>
      oldDelegate.hole != hole;
}

/// `centerDocked` を基準に、FAB を下方向へ [sink] px だけ沈めるロケーション。
/// FAB をボトムバーへ少し食い込ませて一体感を出すために使う。ノッチは
/// FAB の実際の矩形から計算されるため、この位置ずれにノッチも追従する。
class _CenterDockedSunkenFabLocation extends FloatingActionButtonLocation {
  const _CenterDockedSunkenFabLocation(this.sink);

  /// FAB を下へ沈める量（px）。
  final double sink;

  @override
  Offset getOffset(ScaffoldPrelayoutGeometry geometry) {
    final base = FloatingActionButtonLocation.centerDocked.getOffset(geometry);
    return Offset(base.dx, base.dy + sink);
  }

  @override
  String toString() => '_CenterDockedSunkenFabLocation(sink: $sink)';
}

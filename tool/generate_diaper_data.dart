/// おむつマスタデータの変換スクリプト。
///
/// `assets/diaper/` の CSV 3枚（brands.csv / series.csv / sizes.csv）を読み、
/// 検証してから `lib/growth/diaper_master_data.g.dart` を生成する。
/// アプリは生成物だけを読む（実行時に CSV をパースしない）。
///
/// 実行方法（プロジェクトルートで）:
///   dart run tool/generate_diaper_data.dart
///
/// 検証に失敗した場合は、何行目の何が問題かを表示して exit code 1 で停止する。
/// 特に `last_checked` が空の行は「開発者が公式サイトで未確認の下書き」を
/// 意味する意図的な安全装置なので、絶対に緩めないこと。
library;

import 'dart:io';

const _brandsPath = 'assets/diaper/brands.csv';
const _seriesPath = 'assets/diaper/series.csv';
const _sizesPath = 'assets/diaper/sizes.csv';
const _outputPath = 'lib/growth/diaper_master_data.g.dart';

final List<String> _errors = [];
final List<String> _warnings = [];

void main() {
  final brands = _readCsv(_brandsPath);
  final series = _readCsv(_seriesPath);
  final sizes = _readCsv(_sizesPath);

  _validate(brands, series, sizes);

  for (final w in _warnings) {
    stdout.writeln('警告: $w');
  }
  if (_errors.isNotEmpty) {
    for (final e in _errors) {
      stderr.writeln('エラー: $e');
    }
    stderr.writeln('検証に失敗したため生成を中止しました（${_errors.length}件）。');
    exit(1);
  }

  final code = _generate(brands, series, sizes);
  File(_outputPath).writeAsStringSync(code);
  stdout.writeln('生成しました: $_outputPath'
      '（ブランド${brands.rows.length}件・シリーズ${series.rows.length}件・'
      'サイズ${sizes.rows.length}件）');
}

// ── CSV 読み込み ──────────────────────────────────────────────────────────

class _Csv {
  _Csv(this.path, this.header, this.rows, this.rowLineNumbers);

  final String path;
  final List<String> header;

  /// ヘッダを除いたデータ行（列名 → 値）。
  final List<Map<String, String>> rows;

  /// rows[i] が元ファイルの何行目か（1始まり、エラー表示用）。
  final List<int> rowLineNumbers;
}

/// BOM 付き UTF-8 を想定して読み込む（BOM は除去）。
/// 値にカンマを含み得るのは最終列（notes）だけなので、
/// 列数を超えた分は最終列へ結合する簡易パーサで足りる。
_Csv _readCsv(String path) {
  final file = File(path);
  if (!file.existsSync()) {
    stderr.writeln('エラー: $path が見つかりません。プロジェクトルートで実行してください。');
    exit(1);
  }
  var text = file.readAsStringSync();
  if (text.startsWith('\uFEFF')) text = text.substring(1);

  final lines = text.split(RegExp(r'\r?\n'));
  List<String>? header;
  final rows = <Map<String, String>>[];
  final lineNumbers = <int>[];

  for (var i = 0; i < lines.length; i++) {
    final line = lines[i];
    if (line.trim().isEmpty) continue;
    final parts = line.split(',');
    if (header == null) {
      header = [for (final h in parts) h.trim()];
      continue;
    }
    // 列数超過は最終列（notes 等）にカンマが含まれていたとみなして結合する。
    List<String> values;
    if (parts.length > header.length) {
      values = [
        ...parts.sublist(0, header.length - 1),
        parts.sublist(header.length - 1).join(','),
      ];
    } else {
      values = [...parts, for (var j = parts.length; j < header.length; j++) ''];
    }
    rows.add({
      for (var j = 0; j < header.length; j++) header[j]: values[j].trim(),
    });
    lineNumbers.add(i + 1);
  }

  if (header == null) {
    stderr.writeln('エラー: $path にヘッダ行がありません。');
    exit(1);
  }
  return _Csv(path, header, rows, lineNumbers);
}

// ── 検証 ──────────────────────────────────────────────────────────────────

void _validate(_Csv brands, _Csv series, _Csv sizes) {
  void err(_Csv csv, int rowIndex, String message) {
    _errors.add('${csv.path} ${csv.rowLineNumbers[rowIndex]}行目: $message');
  }

  void warn(_Csv csv, int rowIndex, String message) {
    _warnings.add('${csv.path} ${csv.rowLineNumbers[rowIndex]}行目: $message');
  }

  // brands.csv
  final brandIds = <String>{};
  for (var i = 0; i < brands.rows.length; i++) {
    final r = brands.rows[i];
    final id = r['brand_id'] ?? '';
    if (id.isEmpty) err(brands, i, 'brand_id が空です');
    if ((r['brand_name'] ?? '').isEmpty) err(brands, i, 'brand_name が空です');
    if (!brandIds.add(id)) err(brands, i, 'brand_id "$id" が重複しています');
  }

  // series.csv
  final seriesIds = <String>{};
  String? prevBrandId;
  final seenBrandGroups = <String>{};
  for (var i = 0; i < series.rows.length; i++) {
    final r = series.rows[i];
    final id = r['series_id'] ?? '';
    final brandId = r['brand_id'] ?? '';
    if (id.isEmpty) err(series, i, 'series_id が空です');
    if (!seriesIds.add(id)) err(series, i, 'series_id "$id" が重複しています');
    if (brandId.isEmpty) {
      err(series, i, 'brand_id が空です');
    } else if (!brandIds.contains(brandId)) {
      err(series, i, 'brand_id "$brandId" が brands.csv に存在しません');
    }
    if ((r['series_name'] ?? '').isEmpty) err(series, i, 'series_name が空です');
    if ((r['source_url'] ?? '').isEmpty) err(series, i, 'source_url が空です');

    // 安全装置: last_checked が空＝未確認の下書き。生成を止める。
    final lastChecked = r['last_checked'] ?? '';
    if (lastChecked.isEmpty) {
      err(series, i,
          'last_checked が空です（公式サイトで確認して日付を入れるまで生成できません）');
    } else if (_parseDate(lastChecked) == null) {
      err(series, i,
          'last_checked "$lastChecked" を日付として解釈できません'
          '（YYYY-MM-DD または YYYY/M/D）');
    }

    // ── バッジ（3色＋アイコン）の検証 ──
    // ベース3色は必須。#RRGGBB 形式のみ受理する。
    for (final col in ['badge_color_bg', 'badge_color_icon', 'badge_color_ring']) {
      final v = r[col] ?? '';
      if (v.isEmpty) {
        err(series, i, '$col が空です（バッジのベース3色は必須です）');
      } else if (!_isHexColor(v)) {
        err(series, i, '$col "$v" が #RRGGBB 形式ではありません');
      }
    }
    // 背景とアイコンが同色だとアイコンが見えなくなる。
    final bg = r['badge_color_bg'] ?? '';
    final icon = r['badge_color_icon'] ?? '';
    if (bg.isNotEmpty && bg.toUpperCase() == icon.toUpperCase()) {
      err(series, i, 'badge_color_bg と badge_color_icon が同一色です'
          '（アイコンが背景に溶けて見えなくなります）');
    }

    // 上書き列（tape / pants / boy / girl）は「3列そろって入れる」が原則。
    final overrides = <String, bool>{};
    for (final suffix in ['tape', 'pants', 'boy', 'girl']) {
      final values = [
        r['badge_color_bg_$suffix'] ?? '',
        r['badge_color_icon_$suffix'] ?? '',
        r['badge_color_ring_$suffix'] ?? '',
      ];
      final filled = values.where((v) => v.isNotEmpty).length;
      if (filled != 0 && filled != 3) {
        err(series, i, 'badge_color_*_$suffix は3列そろって入れてください'
            '（現在 $filled/3 列のみ）');
      }
      for (final v in values) {
        if (v.isNotEmpty && !_isHexColor(v)) {
          err(series, i, 'badge_color_*_$suffix "$v" が #RRGGBB 形式ではありません');
        }
      }
      if (filled == 3 &&
          values[0].toUpperCase() == values[1].toUpperCase()) {
        err(series, i, 'badge_color_bg_$suffix と badge_color_icon_$suffix が'
            '同一色です');
      }
      overrides[suffix] = filled == 3;
    }
    // タイプ別上書きと性別別上書きの併用は、優先順位が未確認のため拒否する
    // （仕様書の指示：両方を同時に持つデータが出てきたら実装前に要確認）。
    final hasTypeOverride = overrides['tape']! || overrides['pants']!;
    final hasGenderOverride = overrides['boy']! || overrides['girl']!;
    if (hasTypeOverride && hasGenderOverride) {
      err(series, i, 'タイプ別上書きと性別別上書きを同時に持っています。'
          '優先順位が未定義のため、仕様を確認してから対応してください');
    }

    // カテゴリ（アイコン選択用）。想定外の値はタイプミスとして止める。
    const validCategories = {'', 'night', 'swim', 'training', 'duration'};
    final category = r['category'] ?? '';
    if (!validCategories.contains(category)) {
      err(series, i, 'category "$category" は night / swim / training / '
          'duration / 空 のいずれかにしてください');
    }

    // 色が実物のパッケージで未確認の行は警告のみ（生成は続行する）。
    if ((r['badge_color_confirmed'] ?? '').isEmpty) {
      warn(series, i, 'badge_color_confirmed が空です'
          '（バッジ色が実物のパッケージで未確認の下書きです）');
    }

    // 同じブランドのシリーズ行が連続していない場合は警告（表示順が飛び飛び）。
    if (brandId.isNotEmpty && brandId != prevBrandId) {
      if (!seenBrandGroups.add(brandId)) {
        warn(series, i,
            'ブランド "$brandId" のシリーズ行が連続していません（表示順が飛び飛びになります）');
      }
      prevBrandId = brandId;
    }
  }

  // 各ブランドに最低1つのシリーズがあること。
  final brandsWithSeries = {for (final r in series.rows) r['brand_id'] ?? ''};
  for (var i = 0; i < brands.rows.length; i++) {
    final id = brands.rows[i]['brand_id'] ?? '';
    if (id.isNotEmpty && !brandsWithSeries.contains(id)) {
      err(brands, i, 'ブランド "$id" に対応する series.csv の行がありません');
    }
  }

  // sizes.csv
  final sizesBySeriesType = <String, List<({int rowIndex, double min, double max})>>{};
  for (var i = 0; i < sizes.rows.length; i++) {
    final r = sizes.rows[i];
    final seriesId = r['series_id'] ?? '';
    final type = r['type'] ?? '';
    if (seriesId.isEmpty) {
      err(sizes, i, 'series_id が空です');
    } else if (!seriesIds.contains(seriesId)) {
      err(sizes, i, 'series_id "$seriesId" が series.csv に存在しません');
    }
    if (type != 'tape' && type != 'pants') {
      err(sizes, i, 'type "$type" は tape / pants のいずれかにしてください');
    }
    if ((r['size_label'] ?? '').isEmpty) err(sizes, i, 'size_label が空です');

    final min = double.tryParse(r['min_kg'] ?? '');
    final max = double.tryParse(r['max_kg'] ?? '');
    if (min == null) err(sizes, i, 'min_kg "${r['min_kg']}" を数値として解釈できません');
    if (max == null) err(sizes, i, 'max_kg "${r['max_kg']}" を数値として解釈できません');
    if (min != null && max != null) {
      if (min >= max) err(sizes, i, 'min_kg($min) < max_kg($max) になっていません');
      sizesBySeriesType
          .putIfAbsent('$seriesId/$type', () => [])
          .add((rowIndex: i, min: min, max: max));
    }
  }

  // 各シリーズに最低1つのサイズ行があること。
  final seriesWithSizes = {for (final r in sizes.rows) r['series_id'] ?? ''};
  for (var i = 0; i < series.rows.length; i++) {
    final id = series.rows[i]['series_id'] ?? '';
    if (id.isNotEmpty && !seriesWithSizes.contains(id)) {
      err(series, i, 'シリーズ "$id" に対応する sizes.csv の行がありません');
    }
  }

  // はしごの順序検証（行順のまま）。重複・内包は正常なので落とさない。
  for (final entry in sizesBySeriesType.entries) {
    final ladder = entry.value;
    for (var i = 1; i < ladder.length; i++) {
      final prev = ladder[i - 1];
      final cur = ladder[i];
      if (cur.min < prev.min) {
        err(sizes, cur.rowIndex,
            '${entry.key}: min_kg が前の行より小さくなっています（並び順はそのまま「はしご」の順です）');
      } else if (cur.min == prev.min && cur.max <= prev.max) {
        err(sizes, cur.rowIndex,
            '${entry.key}: min_kg が同値の場合は max_kg が厳密に大きくなる必要があります');
      }
      // 重複は正常だが、隙間は入力ミスの可能性が高いので警告。
      if (cur.min > prev.max) {
        warn(sizes, cur.rowIndex,
            '${entry.key}: 前のサイズ（上限${prev.max}kg）との間に隙間があります'
            '（下限${cur.min}kg）。公表値の入力ミスでないか確認してください');
      }
    }
  }
}

/// '#RRGGBB' 形式の色か。
bool _isHexColor(String s) => RegExp(r'^#[0-9A-Fa-f]{6}$').hasMatch(s);

/// YYYY-MM-DD / YYYY/M/D の両形式を受理する。
DateTime? _parseDate(String s) {
  final m = RegExp(r'^(\d{4})[-/](\d{1,2})[-/](\d{1,2})$').firstMatch(s);
  if (m == null) return null;
  final year = int.parse(m.group(1)!);
  final month = int.parse(m.group(2)!);
  final day = int.parse(m.group(3)!);
  if (month < 1 || month > 12 || day < 1 || day > 31) return null;
  return DateTime(year, month, day);
}

String _isoDate(DateTime d) =>
    '${d.year.toString().padLeft(4, '0')}-'
    '${d.month.toString().padLeft(2, '0')}-'
    '${d.day.toString().padLeft(2, '0')}';

// ── 生成 ──────────────────────────────────────────────────────────────────

String _dartStr(String s) {
  final escaped = s
      .replaceAll(r'\', r'\\')
      .replaceAll("'", r"\'")
      .replaceAll(r'$', r'\$');
  return "'$escaped'";
}

String _dartDouble(double v) => v.toStringAsFixed(v == v.roundToDouble() ? 1 : 2);

/// バッジ3色の DiaperBadgeColors 式を作る（suffix='' はベース色）。
/// 3列とも空なら null（＝上書きなし）。
String? _badgeColorsExpr(Map<String, String> row, String suffix) {
  final bg = row['badge_color_bg$suffix'] ?? '';
  final icon = row['badge_color_icon$suffix'] ?? '';
  final ring = row['badge_color_ring$suffix'] ?? '';
  if (bg.isEmpty && icon.isEmpty && ring.isEmpty) return null;
  return 'DiaperBadgeColors(bg: ${_dartStr(bg)}, '
      'icon: ${_dartStr(icon)}, ring: ${_dartStr(ring)})';
}

String _generate(_Csv brands, _Csv series, _Csv sizes) {
  final buf = StringBuffer()
    ..writeln('// 自動生成ファイル。手で編集しないこと。')
    ..writeln('// tool/generate_diaper_data.dart が assets/diaper/*.csv から生成する。')
    ..writeln('// データを直すときは CSV を編集して再生成すること:')
    ..writeln('//   dart run tool/generate_diaper_data.dart')
    ..writeln('// 体重帯は各社公式サイトの公表値（出典・確認日は series.csv 参照）。')
    ..writeln()
    ..writeln("import 'diaper_master.dart';")
    ..writeln()
    ..writeln('/// 全ブランドのマスタデータ（CSV の行順を保持）。')
    ..writeln('const List<DiaperBrand> kDiaperBrands = [');

  for (final b in brands.rows) {
    final brandId = b['brand_id']!;
    final maker = b['maker_name'] ?? '';
    buf
      ..writeln('  DiaperBrand(')
      ..writeln('    id: ${_dartStr(brandId)},')
      ..writeln('    displayName: ${_dartStr(b['brand_name']!)},');
    if (maker.isNotEmpty) {
      buf.writeln('    makerName: ${_dartStr(maker)},');
    }
    buf.writeln('    series: [');

    for (final s in series.rows) {
      if (s['brand_id'] != brandId) continue;
      final seriesId = s['series_id']!;
      final nameTape = s['series_name_tape'] ?? '';
      final namePants = s['series_name_pants'] ?? '';
      final lastChecked = _isoDate(_parseDate(s['last_checked']!)!);
      buf
        ..writeln('      DiaperSeries(')
        ..writeln('        id: ${_dartStr(seriesId)},')
        ..writeln('        brandId: ${_dartStr(brandId)},')
        ..writeln('        displayName: ${_dartStr(s['series_name']!)},');
      if (nameTape.isNotEmpty) {
        buf.writeln('        displayNameTape: ${_dartStr(nameTape)},');
      }
      if (namePants.isNotEmpty) {
        buf.writeln('        displayNamePants: ${_dartStr(namePants)},');
      }
      buf.writeln('        bands: {');
      for (final type in ['tape', 'pants']) {
        final rows = [
          for (final z in sizes.rows)
            if (z['series_id'] == seriesId && z['type'] == type) z,
        ];
        if (rows.isEmpty) continue;
        buf.writeln('          DiaperType.$type: [');
        for (final z in rows) {
          buf.writeln(
              '            DiaperSizeBand(sizeLabel: ${_dartStr(z['size_label']!)}, '
              'minKg: ${_dartDouble(double.parse(z['min_kg']!))}, '
              'maxKg: ${_dartDouble(double.parse(z['max_kg']!))}),');
        }
        buf.writeln('          ],');
      }
      buf
        ..writeln('        },')
        ..writeln('        sourceUrl: ${_dartStr(s['source_url']!)},')
        ..writeln('        lastChecked: ${_dartStr(lastChecked)},')
        ..writeln('        badgeColors: ${_badgeColorsExpr(s, '')!},');
      final tape = _badgeColorsExpr(s, '_tape');
      final pants = _badgeColorsExpr(s, '_pants');
      final boy = _badgeColorsExpr(s, '_boy');
      final girl = _badgeColorsExpr(s, '_girl');
      if (tape != null) buf.writeln('        badgeColorsTape: $tape,');
      if (pants != null) buf.writeln('        badgeColorsPants: $pants,');
      if (boy != null) buf.writeln('        badgeColorsBoy: $boy,');
      if (girl != null) buf.writeln('        badgeColorsGirl: $girl,');
      final category = s['category'] ?? '';
      if (category.isNotEmpty) {
        buf.writeln('        category: ${_dartStr(category)},');
      }
      buf.writeln('      ),');
    }
    buf
      ..writeln('    ],')
      ..writeln('  ),');
  }
  buf.writeln('];');
  return buf.toString();
}

/// スクショ撮影用のダミーデータ（バックアップJSON）を生成するツール。
///
/// アプリの LMS 基準値（GrowthLms2000）を使い、基準曲線に沿って
/// なめらかに推移する現実的な記録を作る。出力したファイルは
/// アプリの「設定 → バックアップを読み込む」で取り込める。
///
/// 実行: dart run tool/generate_screenshot_data.dart
/// 出力: tool/screenshot-data.json
library;

import 'dart:convert';
import 'dart:io';
import 'dart:math' as math;

import 'package:grow_app/growth/growth_lms_2000.dart';

void main() {
  final children = [_haruto(), _yui()];
  final json = const JsonEncoder.withIndent('  ').convert({
    'app': 'grow_app',
    'format': 1,
    'exportedAt': DateTime.now().toIso8601String(),
    'children': children,
  });
  final out = File('tool/screenshot-data.json')..writeAsStringSync(json);
  stdout.writeln('書き出しました: ${out.path}');
  for (final c in children) {
    stdout.writeln(
      '  ${c['name']}: 記録${(c['growthRecords'] as List).length}件 '
      '足長${(c['footMeasurements'] as List).length}件 '
      '購入${(c['shoePurchases'] as List).length}件',
    );
  }
}

double _round1(double v) => (v * 10).roundToDouble() / 10;

DateTime _addMonths(DateTime base, int months) =>
    DateTime(base.year, base.month + months, base.day);

List<Map<String, dynamic>> _records({
  required String idPrefix,
  required DateTime birthDate,
  required bool isBoy,
  required List<int> months,
  required double heightZ,
  required double weightZ,
}) {
  final hRef = GrowthLms2000.heightRef(isBoy: isBoy);
  final wRef = GrowthLms2000.weightRef(isBoy: isBoy);
  return [
    for (final m in months)
      {
        'id': '${idPrefix}_$m',
        'date': _addMonths(birthDate, m).toIso8601String(),
        // 基準SDのまわりを小さくゆらがせて「実測っぽさ」を出す
        // （乱数ではなく正弦波なので、生成のたびに同じ結果になる）。
        'heightCm': _round1(
          hRef.valueAtZ(m.toDouble(), heightZ + 0.07 * math.sin(m * 0.9)),
        ),
        'weightKg': _round1(
          wRef.valueAtZ(m.toDouble(), weightZ + 0.09 * math.sin(m * 0.7 + 1)),
        ),
      },
  ];
}

/// 1人目：はると（2歳2ヶ月・男の子）。
/// おむつガイドON。体重約12.6kgで、3枠が「シリーズ最大」「ゆらぎ（L→XL）」
/// 「クリーン＋使える見込み」の3パターンに分かれるよう調整してある。
Map<String, dynamic> _haruto() {
  final birthDate = DateTime(2024, 5, 10);
  return {
    'id': 'demo_haruto',
    'name': 'はると',
    'birthDate': birthDate.toIso8601String(),
    'gender': 'male',
    'iconIndex': 0,
    'photoBytes': null,
    'themeColor': 0xFF7FA6D6,
    'useCorrectedAge': false,
    'expectedBirthDate': null,
    'fatherHeightCm': 172.0,
    'motherHeightCm': 158.0,
    'birthdayCelebrationEnabled': true,
    'diaperGuideEnabled': true,
    // 起動直後にお祝いダイアログが出ないよう、過去の誕生日は祝済みにする。
    'celebratedBirthdayAges': [1, 2],
    'birthdayMemories': <Map<String, dynamic>>[],
    'footMeasurements': [
      {'date': '2026-02-15T10:00:00.000', 'footLengthCm': 13.1},
      {'date': '2026-07-20T10:00:00.000', 'footLengthCm': 13.6},
    ],
    'shoePurchases': [
      {'date': '2025-11-03T10:00:00.000', 'sizeCm': 14.0},
      {'date': '2026-05-05T10:00:00.000', 'sizeCm': 14.5},
    ],
    'diaperSlots': [
      {'slotIndex': 0, 'seriesId': 'pampers_sarasara', 'type': 'tape'},
      {'slotIndex': 1, 'seriesId': 'mamypoko_std', 'type': 'pants'},
      {'slotIndex': 2, 'seriesId': 'moony_oyasumi', 'type': 'pants'},
    ],
    'diaperGuideLastOpenedAt': '2026-07-28T09:00:00.000',
    'diaperGuideHideSuggestedAt': null,
    'growthRecords': _records(
      idPrefix: 'demo_haruto',
      birthDate: birthDate,
      isBoy: true,
      // 0〜1歳は毎月、その後は2ヶ月ごと（直近は2026年7月10日）。
      // 体重は約12.5kg（+0.5SD）に調整：おむつ3枠が
      // シリーズ最大／ゆらぎ（L→XL）／クリーン＋使える見込み に分かれる。
      months: [for (var m = 0; m <= 12; m++) m, 14, 16, 18, 20, 22, 24, 26],
      heightZ: 0.5,
      weightZ: 0.5,
    ),
  };
}

/// 2人目：ゆい（4歳8ヶ月・女の子）。おむつ卒業済みで洋服・靴のみ。
Map<String, dynamic> _yui() {
  final birthDate = DateTime(2021, 11, 20);
  return {
    'id': 'demo_yui',
    'name': 'ゆい',
    'birthDate': birthDate.toIso8601String(),
    'gender': 'female',
    'iconIndex': 1,
    'photoBytes': null,
    'themeColor': 0xFFDDA0AA,
    'useCorrectedAge': false,
    'expectedBirthDate': null,
    'fatherHeightCm': 172.0,
    'motherHeightCm': 158.0,
    'birthdayCelebrationEnabled': true,
    'celebratedBirthdayAges': [1, 2, 3, 4],
    'diaperGuideEnabled': false,
    'birthdayMemories': <Map<String, dynamic>>[],
    'footMeasurements': [
      {'date': '2026-01-12T10:00:00.000', 'footLengthCm': 16.2},
      {'date': '2026-06-28T10:00:00.000', 'footLengthCm': 16.6},
    ],
    'shoePurchases': [
      {'date': '2025-09-15T10:00:00.000', 'sizeCm': 17.0},
      {'date': '2026-03-08T10:00:00.000', 'sizeCm': 17.5},
    ],
    'diaperSlots': <Map<String, dynamic>>[],
    'diaperGuideLastOpenedAt': null,
    'diaperGuideHideSuggestedAt': null,
    'growthRecords': _records(
      idPrefix: 'demo_yui',
      birthDate: birthDate,
      isBoy: false,
      // 0〜1歳は2ヶ月ごと、その後は3〜4ヶ月ごと（直近は2026年7月20日）。
      months: [0, 2, 4, 6, 8, 10, 12, 15, 18, 21, 24, 28, 32, 36, 40, 44, 48, 52, 56],
      heightZ: 0.25,
      weightZ: 0.05,
    ),
  };
}

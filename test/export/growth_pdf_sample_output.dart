// 一時的な目視確認用：サンプル PDF を build/ に書き出す。
// （通常のテストスイートからは除外して問題ないファイル）
import 'dart:io';

import 'package:flutter_test/flutter_test.dart';
import 'package:grow_app/export/growth_pdf.dart';
import 'package:grow_app/models/child_profile.dart';
import 'package:grow_app/models/gender.dart';
import 'package:grow_app/models/growth_record.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  test('サンプル PDF を書き出す', () async {
    final child = ChildProfile(
      id: 'sample',
      name: 'たろう',
      birthDate: DateTime(2023, 5, 10),
      gender: Gender.male,
      fatherHeightCm: 172,
      motherHeightCm: 158,
      growthRecords: [
        GrowthRecord(
          id: 'r1',
          date: DateTime(2023, 6, 10),
          heightCm: 55.2,
          weightKg: 4.6,
        ),
        GrowthRecord(
          id: 'r2',
          date: DateTime(2023, 9, 10),
          heightCm: 63.5,
          weightKg: 7.0,
        ),
        GrowthRecord(
          id: 'r3',
          date: DateTime(2024, 3, 10),
          heightCm: 72.1,
          weightKg: 9.2,
        ),
        GrowthRecord(
          id: 'r4',
          date: DateTime(2024, 11, 10),
          heightCm: 79.5,
          weightKg: 10.6,
        ),
        GrowthRecord(id: 'r5', date: DateTime(2025, 5, 10), heightCm: 85.0),
      ],
    );
    final bytes = await GrowthPdf.build(child: child);
    final file = File('build/sample_growth_report.pdf');
    file.parent.createSync(recursive: true);
    file.writeAsBytesSync(bytes);
  });

  test('12歳モードのサンプル PDF を書き出す', () async {
    final child = ChildProfile(
      id: 'sample12',
      name: 'はなこ',
      birthDate: DateTime(2015, 4, 1),
      gender: Gender.female,
      growthRecords: [
        for (var year = 1; year <= 11; year++)
          GrowthRecord(
            id: 'y$year',
            date: DateTime(2015 + year, 4, 1),
            heightCm: 70.0 + year * 7.0,
            weightKg: 8.0 + year * 2.8,
          ),
      ],
    );
    final bytes = await GrowthPdf.build(child: child);
    final file = File('build/sample_mode12.pdf');
    file.parent.createSync(recursive: true);
    file.writeAsBytesSync(bytes);
  });
}

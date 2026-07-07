import 'dart:convert';

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:grow_app/backup/growth_backup.dart';
import 'package:grow_app/models/child_profile.dart';
import 'package:grow_app/models/gender.dart';
import 'package:grow_app/models/growth_record.dart';
import 'package:grow_app/models/shoe_records.dart';

void main() {
  ChildProfile sampleChild(String id) => ChildProfile(
        id: id,
        name: 'テスト$id',
        birthDate: DateTime(2023, 4, 1),
        gender: Gender.female,
        iconIndex: 1,
        themeColor: const Color(0xFFDDA0AA),
        fatherHeightCm: 172,
        motherHeightCm: 158,
        growthRecords: [
          GrowthRecord(
            id: '${id}_r1',
            date: DateTime(2024, 4, 1),
            heightCm: 75.5,
            weightKg: 9.42,
          ),
        ],
        footMeasurements: [
          FootMeasurement(date: DateTime(2026, 5, 1), footLengthCm: 14.2),
        ],
        shoePurchases: [
          ShoePurchase(date: DateTime(2026, 5, 3), sizeCm: 15.0),
        ],
      );

  test('書き出したバックアップを読み込むと全データが一致する', () {
    final source = [sampleChild('c1'), sampleChild('c2')];
    final restored = decodeBackupJson(encodeBackupJson(source));

    expect(restored, hasLength(2));
    final a = source.first;
    final b = restored.first;
    expect(b.id, a.id);
    expect(b.name, a.name);
    expect(b.birthDate, a.birthDate);
    expect(b.gender, a.gender);
    expect(b.fatherHeightCm, a.fatherHeightCm);
    expect(b.growthRecords, hasLength(1));
    expect(b.growthRecords.first.heightCm, 75.5);
    expect(b.growthRecords.first.weightKg, 9.42);
    expect(b.footMeasurements.first.footLengthCm, 14.2);
    expect(b.shoePurchases.first.sizeCm, 15.0);
  });

  test('JSONでないファイルはエラーメッセージ付きで拒否される', () {
    expect(
      () => decodeBackupJson('これはバックアップではありません'),
      throwsA(isA<BackupDecodeException>()),
    );
  });

  test('別アプリのJSONは拒否される', () {
    expect(
      () => decodeBackupJson(jsonEncode({'app': 'other', 'children': []})),
      throwsA(isA<BackupDecodeException>()),
    );
  });

  test('未来のフォーマットバージョンは拒否される', () {
    final json = jsonEncode({
      'app': 'grow_app',
      'format': backupFormatVersion + 1,
      'children': [],
    });
    expect(
      () => decodeBackupJson(json),
      throwsA(isA<BackupDecodeException>()),
    );
  });

  test('お子様が空のバックアップは拒否される', () {
    final json = jsonEncode({
      'app': 'grow_app',
      'format': backupFormatVersion,
      'children': <Object>[],
    });
    expect(
      () => decodeBackupJson(json),
      throwsA(isA<BackupDecodeException>()),
    );
  });
}

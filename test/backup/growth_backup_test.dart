import 'dart:convert';
import 'dart:typed_data';

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:grow_app/backup/growth_backup.dart';
import 'package:grow_app/models/birthday_memory.dart';
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

  ChildProfile childWithPhotos(String id) {
    final child = sampleChild(id);
    child.photoBytes = Uint8List.fromList([1, 2, 3]);
    child.birthdayMemories = [
      BirthdayMemory(
        age: 1,
        savedAt: DateTime(2024, 4, 1),
        photoBytes: Uint8List.fromList([4, 5, 6]),
        photoAlignX: 0.5,
        photoScale: 2.0,
        heightCm: 75.0,
        note: '1歳のおたんじょうび',
      ),
    ];
    return child;
  }

  test('includePhotos: false で写真だけ除外され、他のデータは保持される', () {
    final source = [childWithPhotos('c1')];
    final restored =
        decodeBackupJson(encodeBackupJson(source, includePhotos: false));

    final r = restored.single;
    expect(r.photoBytes, isNull);
    expect(r.birthdayMemories.single.photoBytes, isNull);
    // 写真以外の情報は残る。
    expect(r.name, source.single.name);
    expect(r.birthdayMemories.single.age, 1);
    expect(r.birthdayMemories.single.heightCm, 75.0);
    expect(r.birthdayMemories.single.note, '1歳のおたんじょうび');
    expect(r.growthRecords.single.heightCm, 75.5);
  });

  test('includePhotos 既定値（手動バックアップ）では写真が含まれる', () {
    final source = [childWithPhotos('c1')];
    final restored = decodeBackupJson(encodeBackupJson(source));

    final r = restored.single;
    expect(r.photoBytes, Uint8List.fromList([1, 2, 3]));
    expect(
      r.birthdayMemories.single.photoBytes,
      Uint8List.fromList([4, 5, 6]),
    );
  });

  test('mergeLocalPhotos：同じIDのお子様の写真が端末側から引き継がれる', () {
    // クラウド復元＝写真なしのデータ。
    final restored = decodeBackupJson(
      encodeBackupJson([childWithPhotos('c1')], includePhotos: false),
    );
    final local = [childWithPhotos('c1')];

    final merged = mergeLocalPhotos(restored: restored, local: local);

    final m = merged.single;
    expect(m.photoBytes, Uint8List.fromList([1, 2, 3]));
    final memory = m.birthdayMemories.single;
    expect(memory.photoBytes, Uint8List.fromList([4, 5, 6]));
    // 表示位置・拡大率も写真とセットで引き継ぐ。
    expect(memory.photoAlignX, 0.5);
    expect(memory.photoScale, 2.0);
    // クラウド側のテキスト情報はそのまま。
    expect(memory.note, '1歳のおたんじょうび');
  });

  test('mergeLocalPhotos：IDが違うお子様の写真は引き継がれない', () {
    final restored = decodeBackupJson(
      encodeBackupJson([childWithPhotos('c1')], includePhotos: false),
    );
    final local = [childWithPhotos('other')];

    final merged = mergeLocalPhotos(restored: restored, local: local);

    expect(merged.single.photoBytes, isNull);
    expect(merged.single.birthdayMemories.single.photoBytes, isNull);
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

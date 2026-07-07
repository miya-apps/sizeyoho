import 'package:flutter/material.dart';

enum Gender {
  male('男の子'),
  female('女の子');

  const Gender(this.label);
  final String label;
}

/// アイコン候補（index で管理）
/// ボトムシート先頭の「写真を選ぶ」セルと合わせて 5列×5行（25個）
const List<IconData> kChildIconOptions = [
  // 1行目：基本の顔
  Icons.face,
  Icons.face_5,
  Icons.face_4,
  Icons.face_3,
  // 2行目：表情・顔バリエーション
  Icons.child_care,
  Icons.sentiment_satisfied_alt,
  Icons.face_6,
  Icons.sentiment_very_satisfied,
  Icons.face_2,
  // 3行目：生き物・自然
  Icons.pets,
  Icons.cruelty_free,
  Icons.emoji_nature,
  Icons.local_florist,
  Icons.wb_sunny,
  // 4行目：乗り物・スポーツ
  Icons.toys,
  Icons.train,
  Icons.flight,
  Icons.sports_soccer,
  Icons.pool,
  // 5行目：知育・シンボル
  Icons.menu_book,
  Icons.music_note,
  Icons.star,
  Icons.favorite,
  Icons.card_giftcard,
];

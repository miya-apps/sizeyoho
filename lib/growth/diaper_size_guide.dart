/// おむつガイドの判定ロジックと定数。
///
/// シリーズ内の全サイズを小さい順に並べた「はしご」を作り、隣接する
/// サイズのペアごとに「ゆらぎ区間」を計算する。体重がいずれかのゆらぎ
/// 区間に入っていれば「ゆらぎの中」、どこにも入っていなければ「クリーン」
/// （状態は本質的にこの2つだけ）。
///
/// 「いま使っているサイズ」の記録は存在しない前提で、体重だけから
/// 位置を判定する（開くたびに計算する）。
library;

import '../models/child_profile.dart';
import '../models/gender.dart';
import '../models/growth_record.dart';
import 'clothing_size_guide.dart'
    show ageInMonthsAt, baselineSdLookbackDays, baselineSdMaxSamples;
import 'diaper_master.dart';
import 'growth_lms_2000.dart';
import 'lms_reference.dart';

// ── 定数（調整はここ1か所で行う）────────────────────────────────────────

/// 隙間がある / 接している / 内包・退化のときのゆらぎ幅（±kg）。
const double kDiaperTransitionMarginKg = 0.5;

/// 非表示提案：おむつガイドをこの日数開いていなければ提案する（約3か月）。
/// トリガーは行動ベースのみ。体重・年齢・サイズ到達では絶対に提案しない。
const int kDiaperHideSuggestInactivityDays = 90;

/// 非表示提案：「あとで」の後、この日数は再提案しない（約6か月）。
const int kDiaperHideSuggestCooldownDays = 183;

// ── ゆらぎ区間（隣接ペアごと）────────────────────────────────────────────

/// 隣接ペアの関係の4パターン（§仕様4-6）。
/// 判定は「大きい方の下限 n_min と小さい方の min/max の数値関係」だけで行い、
/// サイズ名（「新生児」など）にはハードコードしない。
enum DiaperTransitionKind {
  /// 隙間がある（n_min > c_max）。現データには存在しない将来向けの安全網。
  gap,

  /// 接している（n_min == c_max）。
  touching,

  /// 真の重複（c_min < n_min < c_max。例：S 4-8 と M 6-11）。
  trueOverlap,

  /// 内包・退化（n_min <= c_min。例：3S小さめ新生児 0-3 と 新生児 0-5）。
  /// 真の重複の式を使うと区間が [0,3] になり常時ゆらぎ判定になるため、
  /// 「小さい方の上限 ± 定数」の狭い窓だけをゆらぎ区間にする。
  contained,
}

/// はしごの隣接ペア1つ分のゆらぎ区間。
class DiaperTransition {
  const DiaperTransition({
    required this.lowerIndex,
    required this.kind,
    required this.zoneMinKg,
    required this.zoneMaxKg,
  });

  /// 小さい方のサイズの、はしご内インデックス（大きい方は +1）。
  final int lowerIndex;

  final DiaperTransitionKind kind;

  /// ゆらぎ区間（両端を含む）。
  final double zoneMinKg;
  final double zoneMaxKg;

  /// ゆらぎ区間の中心（サイズアップ予報のターゲット体重）。
  double get centerKg => (zoneMinKg + zoneMaxKg) / 2;

  /// 「対象体重に入っています」と言い切ってよいか。
  /// 真の重複だけが言い切り可。内包・退化などで言い切ると、大きい方の
  /// 公式下限を下回っているのに「対象」と言うことになり事実と矛盾する。
  bool get allowsAssertiveWording => kind == DiaperTransitionKind.trueOverlap;

  /// 体重がこのペアの「ゆらぎの中」にあるか。
  /// 隙間パターンでは、ゆらぎ区間の外でも隙間の中（どのサイズにも属さない
  /// 体重）であれば「ゆらぎの中」として扱う（宙に浮く状態を作らない）。
  ///
  /// 真の重複は区間そのもの（重複区間）だけを見る。区間に入る手前を
  /// 「接近中」として先取りする接近窓は持たない（ユーザーフィードバックに
  /// より廃止。あくまで区間に入った時点でゆらぎと判定する）。
  bool containsWeight(double weightKg, List<DiaperSizeBand> ladder) {
    if (weightKg >= zoneMinKg && weightKg <= zoneMaxKg) return true;
    if (kind == DiaperTransitionKind.gap) {
      final lower = ladder[lowerIndex];
      final upper = ladder[lowerIndex + 1];
      return weightKg > lower.maxKg && weightKg < upper.minKg;
    }
    return false;
  }

  /// この体重で「対象体重に入っています」と言い切ってよいか。
  /// 真の重複かつ、体重が大きい方の公式下限（＝重複区間の下端）以上のとき
  /// だけ true（接近窓を廃止したため、[containsWeight] が真の重複で true を
  /// 返す時点で常に満たされる）。
  bool allowsAssertiveWordingAt(double weightKg) =>
      allowsAssertiveWording && weightKg >= zoneMinKg;
}

/// はしご全体のゆらぎ区間を隣接ペアごとに求める。
/// はしごが1段しかない場合はペアが存在しないので空リスト（ループ0回）。
List<DiaperTransition> computeDiaperTransitions(List<DiaperSizeBand> ladder) {
  final result = <DiaperTransition>[];
  for (var i = 0; i + 1 < ladder.length; i++) {
    final current = ladder[i];
    final next = ladder[i + 1];

    final DiaperTransitionKind kind;
    final double zoneMin;
    final double zoneMax;

    if (next.minKg > current.maxKg) {
      // 隙間がある：隙間の中点 ± 定数。
      kind = DiaperTransitionKind.gap;
      final mid = (current.maxKg + next.minKg) / 2;
      zoneMin = mid - kDiaperTransitionMarginKg;
      zoneMax = mid + kDiaperTransitionMarginKg;
    } else if (next.minKg == current.maxKg) {
      // 接している：境界点 ± 定数。
      kind = DiaperTransitionKind.touching;
      zoneMin = current.maxKg - kDiaperTransitionMarginKg;
      zoneMax = current.maxKg + kDiaperTransitionMarginKg;
    } else if (next.minKg > current.minKg) {
      // 真の重複：重複区間そのもの。
      kind = DiaperTransitionKind.trueOverlap;
      zoneMin = next.minKg;
      zoneMax = current.maxKg;
    } else {
      // 内包・退化：接している場合と同じ「小さい方の上限 ± 定数」。
      kind = DiaperTransitionKind.contained;
      zoneMin = current.maxKg - kDiaperTransitionMarginKg;
      zoneMax = current.maxKg + kDiaperTransitionMarginKg;
    }

    result.add(DiaperTransition(
      lowerIndex: i,
      kind: kind,
      zoneMinKg: zoneMin,
      zoneMaxKg: zoneMax,
    ));
  }
  return result;
}

// ── 体重の位置判定 ──────────────────────────────────────────────────────

/// 体重とはしごの関係。
enum DiaperFitStatus {
  /// 体重がはしごの最小サイズの下限を下回っている
  /// （パンツ専用シリーズ×新生児期などで起こる。エラーではない）。
  belowRange,

  /// クリーン：どの隣接ペアのゆらぎ区間にも入っていない。
  clean,

  /// ゆらぎの中：いずれかの隣接ペアのゆらぎ区間に入っている。
  inTransition,

  /// 体重がはしごの最大サイズの上限を超えている（§仕様4-9(c)）。
  aboveRange,
}

/// 体重をはしごに照らした判定結果。
class DiaperFitResult {
  const DiaperFitResult({
    required this.status,
    this.currentIndex,
    this.transition,
    this.isMaxSize = false,
    this.assertiveTransition = false,
  });

  final DiaperFitStatus status;

  /// clean 時：いまのサイズのはしご内インデックス。
  /// inTransition 時：ゆらぎ中の小さい方のインデックス（大きい方は +1）。
  /// belowRange / aboveRange 時は null。
  final int? currentIndex;

  /// inTransition 時のゆらぎ区間。
  final DiaperTransition? transition;

  /// clean かつ、そのシリーズの最大サイズにいる（§仕様4-9(a)。予報は出さない）。
  final bool isMaxSize;

  /// inTransition 時：この体重で「対象体重に入っています」と言い切ってよいか
  /// （真の重複のみ true。他の3パターンは公式範囲を外れているため false）。
  /// 表示側はこれを見る。
  final bool assertiveTransition;
}

/// 体重を「はしご」に照らして状態を判定する（機能の核）。
///
/// 優先順位：
/// 1. いずれかのゆらぎ区間に入っていれば「ゆらぎの中」。複数の区間に
///    同時に入る場合（夜用シリーズなど重複が広いデータで起こる）は、
///    最も大きいサイズのペアを採用する（体重がすでに大きい方のペアの
///    条件を満たしている以上、より進んだ段の情報を出すのが実態に合う）。
/// 2. クリーンなら、体重を含む最小のサイズを「いまのサイズ」とする
///    （内包ケースでは小さい方＝例：3S小さめ新生児 が正しい現在地）。
/// 3. どのサイズにも入らなければ、下回り／上回りを判定する。
DiaperFitResult evaluateDiaperFit({
  required List<DiaperSizeBand> ladder,
  required double weightKg,
}) {
  assert(ladder.isNotEmpty, 'はしごが空のタイプは呼び出し側で除外すること');

  final transitions = computeDiaperTransitions(ladder);

  // 1. ゆらぎの中（複数該当時は最も大きいペア＝後方優先）。
  for (final t in transitions.reversed) {
    if (t.containsWeight(weightKg, ladder)) {
      return DiaperFitResult(
        status: DiaperFitStatus.inTransition,
        currentIndex: t.lowerIndex,
        transition: t,
        assertiveTransition: t.allowsAssertiveWordingAt(weightKg),
      );
    }
  }

  // 2. クリーン：体重を含む最小のサイズ。
  for (var i = 0; i < ladder.length; i++) {
    final band = ladder[i];
    if (weightKg >= band.minKg && weightKg <= band.maxKg) {
      final resolved = _resolveCleanIndex(ladder, i, weightKg);
      return DiaperFitResult(
        status: DiaperFitStatus.clean,
        currentIndex: resolved,
        isMaxSize: resolved == ladder.length - 1,
      );
    }
  }

  // 3. はしごの外。
  if (weightKg < ladder.first.minKg) {
    return const DiaperFitResult(status: DiaperFitStatus.belowRange);
  }
  return const DiaperFitResult(status: DiaperFitStatus.aboveRange);
}

/// 推奨サイズの繰り上げ（§仕様変更2・§7）。
///
/// クリーンな体重が、いまのサイズの上限まで [kDiaperTransitionMarginKg] を
/// 切っていて、かつ次のサイズが存在し体重を実際にカバーしている場合は、
/// 次のサイズを「現在の推奨」として繰り上げる（境界ちょうどのサイズを
/// 推奨として見せない）。次のサイズが体重をカバーしていない
/// （隙間パターンなど）場合は繰り上げない：事実に基づかない推奨は出さない。
///
/// 実データでは、この境界±[kDiaperTransitionMarginKg]の範囲は既に
/// [computeDiaperTransitions] のゆらぎ区間に完全に含まれるため、この関数は
/// 基本的に到達しない安全網として働く（ゆらぎ区間の外＝クリーンな時点で、
/// 上限まで既に十分な余裕がある）。
int _resolveCleanIndex(
  List<DiaperSizeBand> ladder,
  int index,
  double weightKg,
) {
  var i = index;
  while (i + 1 < ladder.length) {
    final band = ladder[i];
    final next = ladder[i + 1];
    final pastThreshold = weightKg > band.maxKg - kDiaperTransitionMarginKg;
    final nextCoversWeight = weightKg >= next.minKg && weightKg <= next.maxKg;
    if (!pastThreshold || !nextCoversWeight) break;
    i += 1;
  }
  return i;
}

// ── 体重トレンドとサイズアップ予報 ──────────────────────────────────────

/// 予報の先読み上限（週）。約36ヶ月先まで。
const int kDiaperForecastMaxWeeks = 156;

LmsReference _weightReferenceFor(Gender gender) =>
    GrowthLms2000.weightRef(isBoy: gender == Gender.male);

/// 体重記録のうち最新のもの（無ければ null）。
GrowthRecord? latestWeightRecord(List<GrowthRecord> records) {
  GrowthRecord? latest;
  for (final r in records) {
    if (r.weightKg == null) continue;
    if (latest == null || r.date.isAfter(latest.date)) latest = r;
  }
  return latest;
}

/// 最新測定日から過去 [baselineSdLookbackDays] 日以内の体重記録を
/// 最大 [baselineSdMaxSamples] 件（洋服ガイドの身長版と同じ考え方）。
List<GrowthRecord> recentWeightSamplesForBaseline(List<GrowthRecord> records) {
  final withWeight = records.where((r) => r.weightKg != null).toList()
    ..sort((a, b) => b.date.compareTo(a.date));
  if (withWeight.isEmpty) return [];

  final latest = withWeight.first;
  final cutoff = latest.date.subtract(
    const Duration(days: baselineSdLookbackDays),
  );
  return withWeight
      .where((r) => !r.date.isBefore(cutoff))
      .take(baselineSdMaxSamples)
      .toList();
}

/// 直近の体重記録から「この子の体重トレンド」（SD スコアの平均）を求める。
/// 記録が1件でも算出できる（その1点の Z 値になる）。無ければ null。
double? computeWeightBaselineSd(ChildProfile child) {
  final samples = recentWeightSamplesForBaseline(child.growthRecords);
  if (samples.isEmpty) return null;

  final ref = _weightReferenceFor(child.gender);
  var sum = 0.0;
  for (final r in samples) {
    sum += ref.zScore(ageInMonthsAt(child, r.date), r.weightKg!);
  }
  return sum / samples.length;
}

/// 推定体重が目標体重に到達する時期（1件分）。
class DiaperForecast {
  const DiaperForecast({required this.approxDate, required this.weeksUntil});

  /// 到達予測時期（週単位で探索した日付。表示は「◯年◯月頃」の粒度に丸める）。
  final DateTime approxDate;

  /// 現在からの週数（0 = すでに到達見込み）。
  final int weeksUntil;
}

/// 体重トレンド（SD スコア維持の仮定）で、推定体重が [targetKg] に
/// 到達する時期を週単位で探索する。
///
/// - すでに到達している（現時点の推定体重が目標以上）なら weeksUntil = 0。
/// - [kDiaperForecastMaxWeeks] 以内に到達しない見込みなら null
///   （体重の伸びが緩やかな時期は「当面先」として扱う）。
/// - 体重記録が無く算出できない場合も null。
DiaperForecast? forecastWeightReach({
  required ChildProfile child,
  required double targetKg,
  DateTime? asOf,
}) {
  final baselineSd = computeWeightBaselineSd(child);
  if (baselineSd == null) return null;

  final ref = _weightReferenceFor(child.gender);
  final reference = asOf ?? DateTime.now();
  final currentAgeMonths = ageInMonthsAt(child, reference);

  double weightAtWeek(int weeks) =>
      ref.valueAtZ(currentAgeMonths + weeks * (12 / 52.18), baselineSd);

  for (var w = 0; w <= kDiaperForecastMaxWeeks; w++) {
    if (weightAtWeek(w) >= targetKg) {
      return DiaperForecast(
        approxDate: reference.add(Duration(days: w * 7)),
        weeksUntil: w,
      );
    }
  }
  return null;
}

// ── 週数の表示丸め（§4-8）──────────────────────────────────────────────

/// 週数を表示用の粗い粒度に丸める。
///
/// 予報には誤差があるため、閾値ぎりぎりで表示が頻繁に入れ替わらないよう、
/// 6週を超えたら2週間刻みに丸める（6週以下は1週刻みのまま）。
int roundedDiaperWeeks(int weeks) {
  if (weeks <= 6) return weeks;
  return ((weeks + 1) ~/ 2) * 2;
}

// ── 非表示の提案（§4-10。トリガーは行動ベースのみ） ────────────────────

/// いま非表示の提案を出すべきか。
///
/// - ガイドを一度も開いた記録が無い場合は提案しない
///   （今回が初回の可能性が高く、判断材料が無いため）。
/// - 最後に開いてから [kDiaperHideSuggestInactivityDays] 日以上経過が条件。
/// - 一度提案したら [kDiaperHideSuggestCooldownDays] 日は再提案しない。
bool shouldSuggestHidingDiaperGuide(ChildProfile child, {DateTime? asOf}) {
  final lastOpened = child.diaperGuideLastOpenedAt;
  if (lastOpened == null) return false;

  final reference = asOf ?? DateTime.now();
  final inactiveDays = reference.difference(lastOpened).inDays;
  if (inactiveDays < kDiaperHideSuggestInactivityDays) return false;

  final lastSuggested = child.diaperGuideHideSuggestedAt;
  if (lastSuggested != null &&
      reference.difference(lastSuggested).inDays <
          kDiaperHideSuggestCooldownDays) {
    return false;
  }
  return true;
}

// ── 選択枠1つ分のまとめ計算（画面が使う入口） ───────────────────────────

/// 選択枠1つ分の判定＋予報のまとめ。
class DiaperSlotGuide {
  const DiaperSlotGuide({
    required this.ladder,
    required this.fit,
    this.nextSizeForecast,
    this.lowerSizeEndForecast,
  });

  final List<DiaperSizeBand> ladder;
  final DiaperFitResult fit;

  /// クリーン時：次の隣接ペアの「ゆらぎ区間の上端」に到達する時期
  /// （＝いまのサイズが使える見込み。ゆらぎの中に入った後の
  /// [lowerSizeEndForecast] と同じ目標体重にすることで、状態が
  /// クリーン→ゆらぎの中に変わる瞬間に見込みの週数が不連続に
  /// ジャンプしないようにしている）。
  /// 体重記録不足・当面到達しない・最大サイズ在中なら null。
  final DiaperForecast? nextSizeForecast;

  /// 「◯月頃まで使えそう」の根拠となる到達時期。
  /// - ゆらぎの中（真の重複）時：小さい方のサイズの公式上限
  ///   （＝ゆらぎ区間の上端）に到達する時期。
  /// - クリーンかつ最大サイズ在中時：いまのサイズの公式上限に到達する時期
  ///   （次のサイズが無いため、上限を超えるまでの見込みを示す。
  ///   ユーザーフィードバックにより追加）。
  final DiaperForecast? lowerSizeEndForecast;

  /// クリーン時の現在サイズ／ゆらぎ時の小さい方。
  DiaperSizeBand? get currentBand =>
      fit.currentIndex == null ? null : ladder[fit.currentIndex!];

  /// クリーン時の次のサイズ／ゆらぎ時の大きい方（最大サイズ在中などは null）。
  DiaperSizeBand? get nextBand {
    final i = fit.currentIndex;
    if (i == null || i + 1 >= ladder.length) return null;
    return ladder[i + 1];
  }
}

/// 選択枠1つ分の判定と予報をまとめて計算する（画面はこれだけ呼べばよい）。
///
/// - 体重記録が無い場合は null（画面側で「記録があると表示できます」を出す）。
/// - 判定は最新の実測体重で行う（事実ベース）。予報は体重トレンドで行う。
DiaperSlotGuide? computeDiaperSlotGuide({
  required ChildProfile child,
  required List<DiaperSizeBand> ladder,
  DateTime? asOf,
}) {
  if (ladder.isEmpty) return null;
  final latest = latestWeightRecord(child.growthRecords);
  if (latest == null) return null;

  final fit = evaluateDiaperFit(ladder: ladder, weightKg: latest.weightKg!);
  final transitions = computeDiaperTransitions(ladder);

  DiaperForecast? nextSize;
  DiaperForecast? lowerEnd;
  switch (fit.status) {
    case DiaperFitStatus.clean:
      if (!fit.isMaxSize) {
        // 次の隣接ペアの「ゆらぎ区間の上端」への到達時期。ゆらぎの中に
        // 入った後の lowerSizeEndForecast と同じ目標体重を使うことで、
        // クリーン→ゆらぎの中の境目で見込みが不連続にジャンプしないように
        // する（ユーザーフィードバックにより centerKg から変更）。
        final t = transitions[fit.currentIndex!];
        nextSize = forecastWeightReach(
          child: child,
          targetKg: t.zoneMaxKg,
          asOf: asOf,
        );
        // 判定（実測）と予報（トレンド）のずれで「すでに到達」となった
        // 場合は、時期の表示に意味が無いので出さない。
        if (nextSize != null && nextSize.weeksUntil == 0) nextSize = null;
      } else {
        // 最大サイズ在中：次のサイズは無いが、いまのサイズの公式上限に
        // 到達する時期（＝上限を超えるまでの見込み）は出せる
        // （ユーザーフィードバックにより追加）。
        lowerEnd = forecastWeightReach(
          child: child,
          targetKg: ladder[fit.currentIndex!].maxKg,
          asOf: asOf,
        );
        if (lowerEnd != null && lowerEnd.weeksUntil == 0) lowerEnd = null;
      }
    case DiaperFitStatus.inTransition:
      // 小さい方をいつまで使えそうか（ゆらぎ区間の上端に到達する時期）。
      lowerEnd = forecastWeightReach(
        child: child,
        targetKg: fit.transition!.zoneMaxKg,
        asOf: asOf,
      );
    case DiaperFitStatus.belowRange:
      // 最小サイズの下限に到達する時期（「もう少し大きくなったら」の補足用）。
      nextSize = forecastWeightReach(
        child: child,
        targetKg: ladder.first.minKg,
        asOf: asOf,
      );
      if (nextSize != null && nextSize.weeksUntil == 0) nextSize = null;
    case DiaperFitStatus.aboveRange:
      break;
  }

  return DiaperSlotGuide(
    ladder: ladder,
    fit: fit,
    nextSizeForecast: nextSize,
    lowerSizeEndForecast: lowerEnd,
  );
}

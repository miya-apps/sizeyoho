import 'dart:math' as math;

/// LMS 法（Box-Cox power exponential method）の 1 基準点。
///
/// 小児の身体計測値の分布は年齢ごとに歪む（特に体重）。LMS 法は各年齢の分布を
/// 次の 3 パラメータで表現する：
/// - [l] : Box-Cox 変換のべき（歪度 skewness）。1 で正規分布、≠1 で歪み。
/// - [m] : 中央値 median（＝Z=0 の値）。
/// - [s] : 変動係数 coefficient of variation（ばらつき）。
class LmsEntry {
  const LmsEntry(this.ageMonths, this.l, this.m, this.s);

  /// 月齢（0,1,2…）。年単位データは `年 * 12` で格納する。
  final double ageMonths;
  final double l;
  final double m;
  final double s;
}

/// 性別・項目（身長/体重）ごとの LMS 基準テーブル。
///
/// 0〜24ヶ月は月単位、それ以降は年単位の [LmsEntry] を昇順で保持する。
class LmsReference {
  const LmsReference(this.entries);

  /// 月齢昇順の基準点列。
  final List<LmsEntry> entries;

  /// 指定月齢の L/M/S を単調3次補間で求める（範囲外は端点でクランプ）。
  ///
  /// テーブルの基準点は 3〜6ヶ月刻みと粗いため、線形補間では曲線が
  /// カクカクした折れ線になる。単調3次（Fritsch–Butland 型 PCHIP）は
  /// 基準点を必ず通り、隣接基準点の範囲を飛び出さない滑らかな補間を行う。
  ({double l, double m, double s}) paramsAtMonths(double months) {
    final list = entries;
    if (list.isEmpty) return (l: 1, m: 1, s: 0.1);

    final first = list.first;
    if (months <= first.ageMonths) {
      return (l: first.l, m: first.m, s: first.s);
    }
    final last = list.last;
    if (months >= last.ageMonths) {
      return (l: last.l, m: last.m, s: last.s);
    }

    var i = 0;
    while (i < list.length - 2 && months > list[i + 1].ageMonths) {
      i++;
    }
    return (
      l: _monotoneCubic(i, months, (e) => e.l),
      m: _monotoneCubic(i, months, (e) => e.m),
      s: _monotoneCubic(i, months, (e) => e.s),
    );
  }

  /// 区間 [i, i+1] 上の単調3次エルミート補間。
  double _monotoneCubic(int i, double x, double Function(LmsEntry) f) {
    final x0 = entries[i].ageMonths;
    final x1 = entries[i + 1].ageMonths;
    final y0 = f(entries[i]);
    final y1 = f(entries[i + 1]);
    final h = x1 - x0;
    if (h <= 0) return y0;

    final m0 = _tangent(i, f);
    final m1 = _tangent(i + 1, f);

    final t = (x - x0) / h;
    final t2 = t * t;
    final t3 = t2 * t;
    return y0 * (2 * t3 - 3 * t2 + 1) +
        m0 * h * (t3 - 2 * t2 + t) +
        y1 * (-2 * t3 + 3 * t2) +
        m1 * h * (t3 - t2);
  }

  /// 基準点 [i] における接線勾配（Fritsch–Butland の重み付き調和平均）。
  /// 隣接区間の傾きが逆符号・ゼロなら 0 とし、オーバーシュートを防ぐ。
  double _tangent(int i, double Function(LmsEntry) f) {
    double secant(int j) =>
        (f(entries[j + 1]) - f(entries[j])) /
        (entries[j + 1].ageMonths - entries[j].ageMonths);

    if (i == 0) return secant(0);
    if (i == entries.length - 1) return secant(i - 1);

    final d0 = secant(i - 1);
    final d1 = secant(i);
    if (d0 * d1 <= 0) return 0;

    final h0 = entries[i].ageMonths - entries[i - 1].ageMonths;
    final h1 = entries[i + 1].ageMonths - entries[i].ageMonths;
    return 3 * (h0 + h1) / ((2 * h1 + h0) / d0 + (h1 + 2 * h0) / d1);
  }

  /// 指定月齢・Z スコア（SD）における計測値を LMS 公式で逆算する。
  ///   L ≠ 0 : X = M · (1 + L·S·Z)^(1/L)
  ///   L = 0 : X = M · exp(S·Z)
  double valueAtZ(double months, double z) {
    final p = paramsAtMonths(months);
    if (p.l.abs() < 1e-7) {
      return p.m * math.exp(p.s * z);
    }
    final base = 1 + p.l * p.s * z;
    // 極端な裾で底が非正になる場合は L=0 近似でフォールバックして発散を防ぐ。
    if (base <= 0) {
      return p.m * math.exp(p.s * z);
    }
    return p.m * math.pow(base, 1 / p.l).toDouble();
  }

  /// 指定月齢・計測値の Z スコア（SD）を算出する。
  ///   L ≠ 0 : Z = ((X/M)^L − 1) / (L·S)
  ///   L = 0 : Z = ln(X/M) / S
  double zScore(double months, double value) {
    if (value <= 0) return 0;
    final p = paramsAtMonths(months);
    if (p.l.abs() < 1e-7) {
      return math.log(value / p.m) / p.s;
    }
    return (math.pow(value / p.m, p.l).toDouble() - 1) / (p.l * p.s);
  }
}

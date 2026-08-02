// 自動生成ファイル。手で編集しないこと。
// tool/generate_diaper_data.dart が assets/diaper/*.csv から生成する。
// データを直すときは CSV を編集して再生成すること:
//   dart run tool/generate_diaper_data.dart
// 体重帯は各社公式サイトの公表値（出典・確認日は series.csv 参照）。

import 'diaper_master.dart';

/// 全ブランドのマスタデータ（CSV の行順を保持）。
const List<DiaperBrand> kDiaperBrands = [
  DiaperBrand(
    id: 'pampers',
    displayName: 'パンパース',
    makerName: 'P&G',
    series: [
      DiaperSeries(
        id: 'pampers_sarasara',
        brandId: 'pampers',
        displayName: 'さらさらケア',
        bands: {
          DiaperType.tape: [
            DiaperSizeBand(sizeLabel: '新生児', minKg: 0.0, maxKg: 5.0),
            DiaperSizeBand(sizeLabel: 'S', minKg: 4.0, maxKg: 8.0),
            DiaperSizeBand(sizeLabel: 'M', minKg: 6.0, maxKg: 11.0),
            DiaperSizeBand(sizeLabel: 'L', minKg: 9.0, maxKg: 14.0),
          ],
          DiaperType.pants: [
            DiaperSizeBand(sizeLabel: 'Mはいはい', minKg: 5.0, maxKg: 10.0),
            DiaperSizeBand(sizeLabel: 'Mたっち', minKg: 6.0, maxKg: 12.0),
            DiaperSizeBand(sizeLabel: 'L', minKg: 9.0, maxKg: 14.0),
            DiaperSizeBand(sizeLabel: 'ビッグ', minKg: 12.0, maxKg: 22.0),
            DiaperSizeBand(sizeLabel: 'ビッグより大きい', minKg: 15.0, maxKg: 28.0),
          ],
        },
        sourceUrl: 'https://www.jp.pampers.com/products/pampers-mainline-tape',
        lastChecked: '2026-07-18',
        badgeColors: DiaperBadgeColors(bg: '#01B3AE', icon: '#FFFFFF', ring: '#FA7283'),
      ),
      DiaperSeries(
        id: 'pampers_hadaichi',
        brandId: 'pampers',
        displayName: '肌へのいちばん',
        bands: {
          DiaperType.tape: [
            DiaperSizeBand(sizeLabel: '3S小さめ新生児', minKg: 0.0, maxKg: 3.0),
            DiaperSizeBand(sizeLabel: '新生児', minKg: 0.0, maxKg: 5.0),
            DiaperSizeBand(sizeLabel: 'S', minKg: 4.0, maxKg: 8.0),
            DiaperSizeBand(sizeLabel: 'M', minKg: 6.0, maxKg: 11.0),
            DiaperSizeBand(sizeLabel: 'L', minKg: 9.0, maxKg: 14.0),
          ],
          DiaperType.pants: [
            DiaperSizeBand(sizeLabel: 'Mはいはい', minKg: 5.0, maxKg: 10.0),
            DiaperSizeBand(sizeLabel: 'Mたっち', minKg: 6.0, maxKg: 12.0),
            DiaperSizeBand(sizeLabel: 'L', minKg: 9.0, maxKg: 14.0),
            DiaperSizeBand(sizeLabel: 'ビッグ', minKg: 12.0, maxKg: 22.0),
          ],
        },
        sourceUrl: 'https://www.jp.pampers.com/products/pampers-premium-line-pants',
        lastChecked: '2026-07-18',
        badgeColors: DiaperBadgeColors(bg: '#91CBC2', icon: '#FBF9F7', ring: '#C3A551'),
      ),
      DiaperSeries(
        id: 'pampers_airy',
        brandId: 'pampers',
        displayName: '超吸収エアリーパンツ',
        bands: {
          DiaperType.pants: [
            DiaperSizeBand(sizeLabel: 'M', minKg: 5.0, maxKg: 12.0),
            DiaperSizeBand(sizeLabel: 'L', minKg: 9.0, maxKg: 14.0),
            DiaperSizeBand(sizeLabel: 'ビッグ', minKg: 12.0, maxKg: 22.0),
          ],
        },
        sourceUrl: 'https://www.jp.pampers.com/products/pampers-tsukisei-plus-pants',
        lastChecked: '2026-07-18',
        badgeColors: DiaperBadgeColors(bg: '#71CFF6', icon: '#FEFFFF', ring: '#06B6AE'),
      ),
      DiaperSeries(
        id: 'pampers_oyasumi',
        brandId: 'pampers',
        displayName: 'おやすみパンツ',
        bands: {
          DiaperType.pants: [
            DiaperSizeBand(sizeLabel: 'M', minKg: 5.0, maxKg: 12.0),
            DiaperSizeBand(sizeLabel: 'L', minKg: 9.0, maxKg: 14.0),
            DiaperSizeBand(sizeLabel: 'ビッグ', minKg: 12.0, maxKg: 17.0),
            DiaperSizeBand(sizeLabel: 'ビッグより大きい', minKg: 15.0, maxKg: 28.0),
            DiaperSizeBand(sizeLabel: 'スーパーBIG', minKg: 18.0, maxKg: 35.0),
          ],
        },
        sourceUrl: 'https://www.jp.pampers.com/products/pampers-oyasumipants',
        lastChecked: '2026-07-18',
        badgeColors: DiaperBadgeColors(bg: '#003045', icon: '#FBDD06', ring: '#00B2AD'),
        category: 'night',
      ),
    ],
  ),
  DiaperBrand(
    id: 'merries',
    displayName: 'メリーズ',
    makerName: '花王',
    series: [
      DiaperSeries(
        id: 'merries_first',
        brandId: 'merries',
        displayName: 'ファーストプレミアム',
        bands: {
          DiaperType.tape: [
            DiaperSizeBand(sizeLabel: '新生児(3000gまで)', minKg: 0.0, maxKg: 3.0),
            DiaperSizeBand(sizeLabel: '新生児(5000gまで)', minKg: 0.0, maxKg: 5.0),
            DiaperSizeBand(sizeLabel: 'S', minKg: 4.0, maxKg: 8.0),
            DiaperSizeBand(sizeLabel: 'M', minKg: 6.0, maxKg: 11.0),
          ],
          DiaperType.pants: [
            DiaperSizeBand(sizeLabel: 'S', minKg: 4.0, maxKg: 8.0),
            DiaperSizeBand(sizeLabel: 'M', minKg: 6.0, maxKg: 12.0),
            DiaperSizeBand(sizeLabel: 'L', minKg: 9.0, maxKg: 14.0),
            DiaperSizeBand(sizeLabel: 'ビッグ', minKg: 12.0, maxKg: 22.0),
          ],
        },
        sourceUrl: 'https://www.kao.co.jp/merries/products/fp/',
        lastChecked: '2026-07-18',
        badgeColors: DiaperBadgeColors(bg: '#FBDAD1', icon: '#FEFAF8', ring: '#A88B6C'),
      ),
      DiaperSeries(
        id: 'merries_airthrough',
        brandId: 'merries',
        displayName: '肌さらエアスルー',
        bands: {
          DiaperType.tape: [
            DiaperSizeBand(sizeLabel: '新生児(5000gまで)', minKg: 0.0, maxKg: 5.0),
            DiaperSizeBand(sizeLabel: 'S', minKg: 4.0, maxKg: 8.0),
            DiaperSizeBand(sizeLabel: 'M', minKg: 6.0, maxKg: 11.0),
          ],
          DiaperType.pants: [
            DiaperSizeBand(sizeLabel: 'S', minKg: 4.0, maxKg: 8.0),
            DiaperSizeBand(sizeLabel: 'M', minKg: 6.0, maxKg: 12.0),
            DiaperSizeBand(sizeLabel: 'L', minKg: 9.0, maxKg: 14.0),
            DiaperSizeBand(sizeLabel: 'ビッグ', minKg: 12.0, maxKg: 22.0),
            DiaperSizeBand(sizeLabel: 'ビッグより大きい', minKg: 15.0, maxKg: 28.0),
          ],
        },
        sourceUrl: 'https://www.kao.co.jp/merries/products/air/',
        lastChecked: '2026-07-18',
        badgeColors: DiaperBadgeColors(bg: '#E71F9B', icon: '#FFFFFF', ring: '#0E1D95'),
      ),
      DiaperSeries(
        id: 'merries_gussuri',
        brandId: 'merries',
        displayName: 'ぐっすりパンツ',
        bands: {
          DiaperType.pants: [
            DiaperSizeBand(sizeLabel: 'L', minKg: 9.0, maxKg: 15.0),
            DiaperSizeBand(sizeLabel: 'ビッグ', minKg: 12.0, maxKg: 22.0),
            DiaperSizeBand(sizeLabel: 'ビッグより大きい', minKg: 15.0, maxKg: 28.0),
          ],
        },
        sourceUrl: 'https://www.kao.co.jp/merries/products/night/',
        lastChecked: '2026-07-18',
        badgeColors: DiaperBadgeColors(bg: '#0E1D95', icon: '#FFF317', ring: '#E71F9B'),
        category: 'night',
      ),
    ],
  ),
  DiaperBrand(
    id: 'moony',
    displayName: 'ムーニー',
    makerName: 'ユニ・チャーム',
    series: [
      DiaperSeries(
        id: 'moony_natural',
        brandId: 'moony',
        displayName: '低刺激であんしん',
        bands: {
          DiaperType.tape: [
            DiaperSizeBand(sizeLabel: '新生児(3000gまで)', minKg: 0.0, maxKg: 3.0),
            DiaperSizeBand(sizeLabel: '新生児(5000gまで)', minKg: 0.0, maxKg: 5.0),
            DiaperSizeBand(sizeLabel: 'S', minKg: 4.0, maxKg: 8.0),
            DiaperSizeBand(sizeLabel: 'M', minKg: 6.0, maxKg: 11.0),
          ],
          DiaperType.pants: [
            DiaperSizeBand(sizeLabel: 'S', minKg: 4.0, maxKg: 8.0),
            DiaperSizeBand(sizeLabel: 'M', minKg: 5.0, maxKg: 10.0),
            DiaperSizeBand(sizeLabel: 'L', minKg: 9.0, maxKg: 14.0),
            DiaperSizeBand(sizeLabel: 'ビッグ', minKg: 12.0, maxKg: 22.0),
          ],
        },
        sourceUrl: 'https://jp.moony.com/',
        lastChecked: '2026-07-18',
        badgeColors: DiaperBadgeColors(bg: '#B7CFE3', icon: '#F1EDEA', ring: '#5F1904'),
      ),
      DiaperSeries(
        id: 'moony',
        brandId: 'moony',
        displayName: 'ムーニー',
        displayNameTape: 'ムーニー',
        displayNamePants: 'ムーニーマン',
        bands: {
          DiaperType.tape: [
            DiaperSizeBand(sizeLabel: '新生児(3000gまで)', minKg: 0.0, maxKg: 3.0),
            DiaperSizeBand(sizeLabel: '新生児(5000gまで)', minKg: 0.0, maxKg: 5.0),
            DiaperSizeBand(sizeLabel: 'S', minKg: 4.0, maxKg: 8.0),
            DiaperSizeBand(sizeLabel: 'M', minKg: 6.0, maxKg: 11.0),
            DiaperSizeBand(sizeLabel: 'L', minKg: 9.0, maxKg: 14.0),
          ],
          DiaperType.pants: [
            DiaperSizeBand(sizeLabel: 'S', minKg: 4.0, maxKg: 8.0),
            DiaperSizeBand(sizeLabel: 'Mはいはい', minKg: 5.0, maxKg: 10.0),
            DiaperSizeBand(sizeLabel: 'Mたっち', minKg: 6.0, maxKg: 12.0),
            DiaperSizeBand(sizeLabel: 'L', minKg: 9.0, maxKg: 14.0),
            DiaperSizeBand(sizeLabel: 'ビッグ', minKg: 12.0, maxKg: 22.0),
            DiaperSizeBand(sizeLabel: 'ビッグより大きい', minKg: 13.0, maxKg: 28.0),
            DiaperSizeBand(sizeLabel: 'スーパービッグ', minKg: 18.0, maxKg: 35.0),
          ],
        },
        sourceUrl: 'https://jp.moony.com/ja/products/mn.html',
        lastChecked: '2026-07-18',
        badgeColors: DiaperBadgeColors(bg: '#C1DFF2', icon: '#F5F2F7', ring: '#16234E'),
      ),
      DiaperSeries(
        id: 'moony_oyasumi',
        brandId: 'moony',
        displayName: 'オヤスミマン',
        bands: {
          DiaperType.pants: [
            DiaperSizeBand(sizeLabel: 'M', minKg: 6.0, maxKg: 12.0),
            DiaperSizeBand(sizeLabel: 'L', minKg: 9.0, maxKg: 14.0),
            DiaperSizeBand(sizeLabel: 'ビッグ以上', minKg: 13.0, maxKg: 28.0),
            DiaperSizeBand(sizeLabel: 'スーパービッグ', minKg: 18.0, maxKg: 35.0),
          ],
        },
        sourceUrl: 'https://jp.moony.com/',
        lastChecked: '2026-07-18',
        badgeColors: DiaperBadgeColors(bg: '#009DE2', icon: '#FFD803', ring: '#00509E'),
        category: 'night',
      ),
      DiaperSeries(
        id: 'moony_trepan',
        brandId: 'moony',
        displayName: 'トレパンマン',
        bands: {
          DiaperType.pants: [
            DiaperSizeBand(sizeLabel: 'L', minKg: 9.0, maxKg: 14.0),
            DiaperSizeBand(sizeLabel: 'ビッグ', minKg: 12.0, maxKg: 22.0),
          ],
        },
        sourceUrl: 'https://www.torepanman.jp/ja/home.html',
        lastChecked: '2026-07-18',
        badgeColors: DiaperBadgeColors(bg: '#2BA8BC', icon: '#FFFFFF', ring: '#00429C'),
        badgeColorsBoy: DiaperBadgeColors(bg: '#2BA8BC', icon: '#FFFFFF', ring: '#00429C'),
        badgeColorsGirl: DiaperBadgeColors(bg: '#DD8E91', icon: '#FFFFFF', ring: '#183F94'),
        category: 'training',
      ),
      DiaperSeries(
        id: 'moony_mizuasobi',
        brandId: 'moony',
        displayName: '水あそびパンツ',
        bands: {
          DiaperType.pants: [
            DiaperSizeBand(sizeLabel: 'M', minKg: 6.0, maxKg: 12.0),
            DiaperSizeBand(sizeLabel: 'L', minKg: 9.0, maxKg: 14.0),
            DiaperSizeBand(sizeLabel: 'ビッグ', minKg: 12.0, maxKg: 22.0),
          ],
        },
        sourceUrl: 'https://jp.moony.com/ja/products/mnm/mnm-mizuasobi.html',
        lastChecked: '2026-07-18',
        badgeColors: DiaperBadgeColors(bg: '#A6D1EB', icon: '#FFFFFF', ring: '#201F88'),
        category: 'swim',
      ),
    ],
  ),
  DiaperBrand(
    id: 'goon',
    displayName: 'グーン',
    makerName: '大王製紙',
    series: [
      DiaperSeries(
        id: 'goon_more0',
        brandId: 'goon',
        displayName: 'グーン',
        bands: {
          DiaperType.tape: [
            DiaperSizeBand(sizeLabel: '新生児', minKg: 0.0, maxKg: 5.0),
            DiaperSizeBand(sizeLabel: 'S', minKg: 4.0, maxKg: 8.0),
            DiaperSizeBand(sizeLabel: 'M', minKg: 6.0, maxKg: 11.0),
            DiaperSizeBand(sizeLabel: 'L', minKg: 9.0, maxKg: 14.0),
            DiaperSizeBand(sizeLabel: 'BIG(XL)', minKg: 12.0, maxKg: 20.0),
          ],
          DiaperType.pants: [
            DiaperSizeBand(sizeLabel: 'M', minKg: 6.0, maxKg: 12.0),
            DiaperSizeBand(sizeLabel: 'L', minKg: 9.0, maxKg: 14.0),
            DiaperSizeBand(sizeLabel: 'BIG', minKg: 12.0, maxKg: 22.0),
          ],
        },
        sourceUrl: 'https://www.elleair.jp/product/detail/goon_08_0022',
        lastChecked: '2026-07-18',
        badgeColors: DiaperBadgeColors(bg: '#E1B1D1', icon: '#F1D3B7', ring: '#9BD2E6'),
      ),
      DiaperSeries(
        id: 'goon_chouusu',
        brandId: 'goon',
        displayName: '超うす通気',
        bands: {
          DiaperType.pants: [
            DiaperSizeBand(sizeLabel: 'L', minKg: 9.0, maxKg: 16.0),
            DiaperSizeBand(sizeLabel: 'BIG', minKg: 12.0, maxKg: 24.0),
          ],
        },
        sourceUrl: 'https://www.elleair.jp/goon/',
        lastChecked: '2026-07-18',
        badgeColors: DiaperBadgeColors(bg: '#1D160F', icon: '#F9F7F6', ring: '#BFB487'),
      ),
      DiaperSeries(
        id: 'goon_12h',
        brandId: 'goon',
        displayName: '12時間ぐんぐん吸収',
        bands: {
          DiaperType.pants: [
            DiaperSizeBand(sizeLabel: 'BIG', minKg: 12.0, maxKg: 22.0),
            DiaperSizeBand(sizeLabel: 'BIGより大きい', minKg: 13.0, maxKg: 28.0),
          ],
        },
        sourceUrl: 'https://www.elleair.jp/goon/',
        lastChecked: '2026-07-18',
        badgeColors: DiaperBadgeColors(bg: '#241F80', icon: '#F7CF34', ring: '#C93433'),
        category: 'duration',
      ),
      DiaperSeries(
        id: 'goon_gungun',
        brandId: 'goon',
        displayName: 'ぐんぐん吸収',
        bands: {
          DiaperType.pants: [
            DiaperSizeBand(sizeLabel: 'M', minKg: 6.0, maxKg: 12.0),
            DiaperSizeBand(sizeLabel: 'L', minKg: 9.0, maxKg: 14.0),
            DiaperSizeBand(sizeLabel: 'BIG', minKg: 12.0, maxKg: 22.0),
            DiaperSizeBand(sizeLabel: 'BIGより大きい', minKg: 13.0, maxKg: 28.0),
          ],
        },
        sourceUrl: 'https://www.elleair.jp/goon/',
        lastChecked: '2026-07-18',
        badgeColors: DiaperBadgeColors(bg: '#FDD234', icon: '#FFFFFF', ring: '#D22C25'),
      ),
      DiaperSeries(
        id: 'goon_night',
        brandId: 'goon',
        displayName: 'ナイトシリーズ',
        bands: {
          DiaperType.pants: [
            DiaperSizeBand(sizeLabel: 'ナイトキッズ(90-120cm)', minKg: 13.0, maxKg: 25.0),
            DiaperSizeBand(sizeLabel: 'ナイトジュニア(110-140cm)', minKg: 15.0, maxKg: 35.0),
          ],
        },
        sourceUrl: 'https://www.elleair.jp/goon/',
        lastChecked: '2026-07-18',
        badgeColors: DiaperBadgeColors(bg: '#FFFFFF', icon: '#4AA5DE', ring: '#004993'),
        category: 'night',
      ),
      DiaperSeries(
        id: 'goon_superbig',
        brandId: 'goon',
        displayName: 'スーパーBIG',
        bands: {
          DiaperType.tape: [
            DiaperSizeBand(sizeLabel: 'スーパーBIG', minKg: 15.0, maxKg: 35.0),
          ],
          DiaperType.pants: [
            DiaperSizeBand(sizeLabel: 'スーパーBIG', minKg: 15.0, maxKg: 35.0),
          ],
        },
        sourceUrl: 'https://www.elleair.jp/goon/',
        lastChecked: '2026-07-18',
        badgeColors: DiaperBadgeColors(bg: '#B74895', icon: '#FFEE84', ring: '#AD1E87'),
      ),
      DiaperSeries(
        id: 'goon_swimming',
        brandId: 'goon',
        displayName: 'スイミングパンツ',
        bands: {
          DiaperType.pants: [
            DiaperSizeBand(sizeLabel: 'M', minKg: 6.0, maxKg: 12.0),
            DiaperSizeBand(sizeLabel: 'L', minKg: 9.0, maxKg: 14.0),
            DiaperSizeBand(sizeLabel: 'BIG', minKg: 12.0, maxKg: 20.0),
          ],
        },
        sourceUrl: 'https://www.elleair.jp/goo-n/swimming/',
        lastChecked: '2026-07-18',
        badgeColors: DiaperBadgeColors(bg: '#FFF100', icon: '#FFFFFF', ring: '#0261AC'),
        category: 'swim',
      ),
    ],
  ),
  DiaperBrand(
    id: 'mamypoko',
    displayName: 'マミーポコ',
    makerName: 'ユニ・チャーム',
    series: [
      DiaperSeries(
        id: 'mamypoko_std',
        brandId: 'mamypoko',
        displayName: 'マミーポコ',
        bands: {
          DiaperType.pants: [
            DiaperSizeBand(sizeLabel: 'S', minKg: 4.0, maxKg: 9.0),
            DiaperSizeBand(sizeLabel: 'M', minKg: 6.0, maxKg: 13.0),
            DiaperSizeBand(sizeLabel: 'L', minKg: 9.0, maxKg: 15.0),
            DiaperSizeBand(sizeLabel: 'XL', minKg: 12.0, maxKg: 22.0),
            DiaperSizeBand(sizeLabel: 'XXL', minKg: 13.0, maxKg: 28.0),
          ],
        },
        sourceUrl: 'https://jp.mamypoko.com/',
        lastChecked: '2026-07-18',
        badgeColors: DiaperBadgeColors(bg: '#BA0025', icon: '#FFFFFF', ring: '#910000'),
      ),
      DiaperSeries(
        id: 'mamypoko_night',
        brandId: 'mamypoko',
        displayName: 'マミーポコ夜用',
        bands: {
          DiaperType.pants: [
            DiaperSizeBand(sizeLabel: 'M', minKg: 6.0, maxKg: 13.0),
            DiaperSizeBand(sizeLabel: 'L', minKg: 9.0, maxKg: 15.0),
            DiaperSizeBand(sizeLabel: 'XL', minKg: 12.0, maxKg: 22.0),
            DiaperSizeBand(sizeLabel: 'XXL', minKg: 13.0, maxKg: 28.0),
          ],
        },
        sourceUrl: 'https://jp.mamypoko.com/',
        lastChecked: '2026-07-18',
        badgeColors: DiaperBadgeColors(bg: '#033490', icon: '#FFFFFF', ring: '#910000'),
        category: 'night',
      ),
    ],
  ),
  DiaperBrand(
    id: 'genki',
    displayName: 'Genki!',
    makerName: 'アイリスオーヤマ',
    series: [
      DiaperSeries(
        id: 'genki_std',
        brandId: 'genki',
        displayName: 'Genki!',
        bands: {
          DiaperType.pants: [
            DiaperSizeBand(sizeLabel: 'M', minKg: 6.0, maxKg: 12.0),
            DiaperSizeBand(sizeLabel: 'L', minKg: 9.0, maxKg: 14.0),
            DiaperSizeBand(sizeLabel: 'BIG', minKg: 12.0, maxKg: 22.0),
            DiaperSizeBand(sizeLabel: 'BIGより大きい', minKg: 13.0, maxKg: 28.0),
          ],
        },
        sourceUrl: 'https://www.irisohyama.co.jp/healthcare-portal/genki/baby-omutsu/',
        lastChecked: '2026-07-18',
        badgeColors: DiaperBadgeColors(bg: '#D1E6F5', icon: '#FFFFFF', ring: '#1081C6'),
      ),
    ],
  ),
  DiaperBrand(
    id: 'nishimatsuya',
    displayName: '西松屋',
    makerName: '西松屋チェーン',
    series: [
      DiaperSeries(
        id: 'nishimatsuya_baby',
        brandId: 'nishimatsuya',
        displayName: 'ベビーおむつ',
        displayNameTape: 'ベビーおむつ テープ',
        displayNamePants: 'ベビーパンツ',
        bands: {
          DiaperType.tape: [
            DiaperSizeBand(sizeLabel: 'M', minKg: 6.0, maxKg: 11.0),
          ],
          DiaperType.pants: [
            DiaperSizeBand(sizeLabel: 'L', minKg: 8.0, maxKg: 12.0),
            DiaperSizeBand(sizeLabel: 'ビッグ', minKg: 11.0, maxKg: 14.0),
            DiaperSizeBand(sizeLabel: 'ゆったりBIG', minKg: 12.0, maxKg: 17.0),
          ],
        },
        sourceUrl: 'https://www.24028.jp/ir/wp-content/uploads/sites/5/syohin260115.pdf',
        lastChecked: '2026-07-18',
        badgeColors: DiaperBadgeColors(bg: '#FFFFFF', icon: '#F3C0C8', ring: '#838383'),
      ),
    ],
  ),
];

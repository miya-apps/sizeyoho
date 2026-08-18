/**
 * サイズ選びガイドの記事台帳。
 * 新しい記事はこの配列に1件追加すると、/guide/ のおすすめ枠とカテゴリ別一覧に反映されます。
 * featured は代表記事だけ true にし、おすすめ枠は最大4件に保ちます。
 */
globalThis.SIZEYOHO_GUIDE_ARTICLES = Object.freeze([
  {
    title: "子ども服のサイズ早見表｜年齢・身長別に80〜130cmの目安を解説",
    url: "https://miyaapps.com/sizeyoho/guide/clothes/size-chart/",
    description: "80〜130サイズを一覧で確認。身長を基準に、今の体格と商品実寸まで見る選び方をまとめています。",
    category: "clothes",
    label: "サイズ早見表",
    featured: true,
    order: 10
  },
  {
    title: "90サイズは何歳？身長・体重の目安と80・100で迷うときの選び方",
    url: "https://miyaapps.com/sizeyoho/guide/clothes/90-size-age/",
    description: "90サイズの年齢・身長・体重の目安と、前後のサイズで迷ったときの確認ポイントを解説します。",
    category: "clothes",
    label: "90サイズ",
    featured: false,
    order: 20
  },
  {
    title: "100サイズは何歳？身長の目安と90・110で迷うときの選び方",
    url: "https://miyaapps.com/sizeyoho/guide/clothes/100-size-age/",
    description: "100サイズの目安と、年齢だけでなく現在の身長や商品実寸から選ぶ方法を解説します。",
    category: "clothes",
    label: "100サイズ",
    featured: false,
    order: 30
  },
  {
    title: "110サイズは何歳？身長の目安と100・120で迷うときの選び方",
    url: "https://miyaapps.com/sizeyoho/guide/clothes/110-size-age/",
    description: "110サイズの目安とメーカーごとの違い、前後のサイズで迷ったときの見方を解説します。",
    category: "clothes",
    label: "110サイズ",
    featured: false,
    order: 40
  },
  {
    title: "子ども服はワンサイズ上を買う？大きめ・ジャストサイズの選び方",
    url: "https://miyaapps.com/sizeyoho/guide/clothes/one-size-up/",
    description: "今着る服と来年用を分け、服の種類ごとに大きめを選ぶときの確認ポイントを解説します。",
    category: "clothes",
    label: "大きめ？ジャスト？",
    featured: true,
    order: 50
  },
  {
    title: "来年の子ども服は何サイズ？先買いで迷ったときの選び方",
    url: "https://miyaapps.com/sizeyoho/guide/clothes/next-year-size/",
    description: "今の身長・着る時期・成長記録・商品実寸から、来年用のサイズを考える方法を解説します。",
    category: "clothes",
    label: "来年用・先買い",
    featured: true,
    order: 60
  },
  {
    title: "子どもの靴サイズは何cm？年齢別の目安と足に合う靴の選び方",
    url: "https://miyaapps.com/sizeyoho/guide/shoes/size-guide/",
    description: "年齢別のサイズ目安、足長・足囲・足幅、自宅での測り方、メーカー差までまとめています。",
    category: "shoes",
    label: "年齢別・測り方",
    featured: true,
    order: 10
  },
  {
    title: "子どもの靴はいつサイズアップ？買い替え時期と見分け方",
    url: "https://miyaapps.com/sizeyoho/guide/shoes/size-up/",
    description: "足を測る頻度、つま先の余裕、買い替えサイン、0.5cm・1cmで迷うときの考え方を解説します。",
    category: "shoes",
    label: "サイズアップ",
    featured: false,
    order: 20
  },
  {
    title: "子どもの靴は大きめでいい？0.5cm・1cmで迷うときの選び方",
    url: "https://miyaapps.com/sizeyoho/guide/shoes/too-big/",
    description: "足長へ一律に数字を足さず、メーカーごとの捨て寸、つま先・幅・甲・かかとのフィットから選ぶ方法を解説します。",
    category: "shoes",
    label: "0.5cm？1cm？",
    featured: false,
    order: 30
  }
]);

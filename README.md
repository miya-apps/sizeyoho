# grow_app

A new Flutter project.

## おむつマスタデータの再生成

`assets/diaper/*.csv` を編集したら `dart run tool/generate_diaper_data.dart` を実行して `lib/growth/diaper_master_data.g.dart` を再生成する。

## SEO記事を追加するときのルール

1. `clothes`（子ども服）・`shoes`（靴）・`diapers`（おむつ）・`growth`（身長・成長）のどのカテゴリに属するか決める。
2. `docs/guide/<category>/<slug>/index.html` に個別記事を作成する。公開済みURLはSEO上の理由なく変更しない。
3. `docs/guide/articles.js` にタイトル・URL・説明・カテゴリ・ラベル・おすすめ表示・並び順を1件追加する。これで `/guide/` のカテゴリ別一覧に反映される。
4. 個別記事に、同じカテゴリを中心とした関連記事と `/guide/` へのリンクを設定する。
5. 個別記事に、サイズ予報アプリTOPへ戻る自然なCTAを設置する。
6. `docs/sitemap.xml` に公開URLを追加し、canonical・OGP・構造化データ・パンくず・404・内部リンクを確認する。
7. アプリTOP（`docs/index.html`）には原則として個別記事を追加しない。TOPから記事への入口は `/guide/` の1か所にまとめる。

`featured: true` は代表記事だけに設定する。`/guide/` の「まず読みたいガイド」は先頭4件までの表示に固定しているため、記事数が増えても枠は増えない。

## Getting Started

This project is a starting point for a Flutter application.

A few resources to get you started if this is your first Flutter project:

- [Learn Flutter](https://docs.flutter.dev/get-started/learn-flutter)
- [Write your first Flutter app](https://docs.flutter.dev/get-started/codelab)
- [Flutter learning resources](https://docs.flutter.dev/reference/learning-resources)

For help getting started with Flutter development, view the
[online documentation](https://docs.flutter.dev/), which offers tutorials,
samples, guidance on mobile development, and a full API reference.

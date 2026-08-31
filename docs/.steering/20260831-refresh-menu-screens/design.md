# 設計書

## 方針

既存の単一シーンと画面状態を維持し、メニュー専用の生成ヘルパーを `match_prototype.gd` に追加する。背景は `assets/ui/menu_background.png` を画面全体に拡大表示し、前景は `assets/ui/` のロゴ、フレーム、ボタン、カード、入力欄、準備完了素材を `TextureRect` と透明な `Button` の組み合わせで表示する。

## 画面構成

| 画面 | 主要素材 | 構成 |
| --- | --- | --- |
| タイトル | `logo_title` | 中央ロゴ、開始案内 |
| ホーム | `logo_title`、`panel_frame`、主・副ボタン | 左のオンライン入口、右の各モード入口 |
| オンライン接続 | `logo_title`、`panel_frame`、入力欄、主ボタン | 中央接続パネル |
| オンライン待機 | `logo_title`、`panel_frame`、`card_character`、`button_ready` | 左右のプレイヤー選択カード |
| 練習 | `logo_title`、`panel_frame`、`card_character`、主ボタン | 1人用の選択カード |
| デバッグ | `logo_title`、`panel_frame`、`card_character`、主・副ボタン | P1/P2の並列選択カード |

## 検証

- GDScript のパーサーチェックを行う。
- Godot実行ファイルが利用可能なら起動ログを確認する。
- 対象外の対戦描画・HUD関連に差分がないことを確認する。

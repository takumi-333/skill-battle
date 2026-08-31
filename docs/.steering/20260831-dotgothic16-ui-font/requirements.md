# 要件

## 目的

`resources/DotGothic16` に配置済みの DotGothic16 を、ゲーム内の Control ベース UI で既定フォントとして利用可能にする。

## 機能要件

- `DotGothic16-Regular.ttf` を Godot のテーマリソースから参照する。
- 動的に作成する Label、Button、LineEdit を含む既存 UI が、個別の変更なしに同フォントを継承する。
- CanvasItem の直接描画テキストも同フォントを使用する。
- フォントの OFL ライセンスファイルは既存の配置を維持する。

## 非要件

- UI レイアウト、配色、発光演出の刷新は行わない。
- タイトルロゴ画像は変更しない。

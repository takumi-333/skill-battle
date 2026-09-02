# 設計書

## アーキテクチャ

`main.tscn` のルート直下に `CanvasLayer/UIRoot` を置き、画面ごとの親 `Control` をあらかじめ定義する。`MatchPrototype` は各親を `@onready` で参照し、その子要素を生成・更新する。

```text
MatchPrototype (Node2D: 対戦描画・状態)
└─ UIRoot (CanvasLayer: シーン定義、エディタ編集対象)
   ├─ MenuBackground
   ├─ HUD
   ├─ Lobby
   ├─ Connection
   ├─ Result
   ├─ Navigation
   └─ Challenge
```

## 実装方針

- 各親は `Control` として `.tscn` に保存し、1280×720の既存基準座標を保つ。
- スクリプトの `create_*_ui()` は親そのものを新規作成せず、シーン上の親を取得して既存の子要素を構築する。
- UIの表示切替は既存の親ノード参照を使い、`visible` の挙動を維持する。
- 既存の動的な子要素は次の段階で個別のControlシーンへ移せるよう、画面別の親の下に限定する。

## 検証

- Godotのヘッドレス起動でシーンとスクリプトのパースエラーを確認する。
- 起動時に各UI親が見つかること、および主要画面の切替を確認する。

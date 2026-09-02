# 設計書

各画面を個別のControlシーンとして定義し、`main.tscn` はそれらをインスタンス化する。画面スクリプトは `@onready` 参照でノードを取得し、テキスト、テクスチャ、数値、可視性を更新する。

```text
main.tscn
├─ UIRoot
│  ├─ TitleScreen.tscn
│  ├─ HomeScreen.tscn
│  ├─ OnlineScreen.tscn
│  ├─ LobbyScreen.tscn
│  ├─ Hud.tscn
│  └─ ResultScreen.tscn
└─ ChallengeLayer
   └─ ChallengeScreen.tscn
```

同一画面の固定部品は `.tscn` に置く。プレイヤー数やスキル一覧など可変個数の部品のみを、専用のContainerの子として動的に生成する。

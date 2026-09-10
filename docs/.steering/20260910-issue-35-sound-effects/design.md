# 設計

- 定数で `assets/audio/damaged.mp3`、`game_hit_midheavy.wav`、`skill_miss.mp3`、`writing_sound.wav` をプリロードし、短い単発音は生成した `AudioStreamPlayer` を終了時に解放する。
- ダメージはローカル／P2Pでは権威側の `apply_damage` から再生・P2Pクライアントへ RPC 送信し、Dedicated ServerではHP低下のスナップショット差分で各クライアントが再生する。
- 三叉震槌は着弾時に権威側で再生しP2PクライアントへRPC送信する。Dedicated Serverでは既存の `released` 遷移検出へ追加する。
- ミス表示を開始する処理をヘルパー化して、ローカルとDedicated Serverスナップショットのいずれでも視覚効果と `skill-miss` を一度だけ同時に開始する。
- なぞり音は専用のループ用プレイヤーを保持し、キャンバス内の有効なマウス移動で開始または再開する。無操作を `_process` の短い猶予で検出して停止し、解放・終了では即時停止する。ネットワーク送信はせず、操作した本人だけが聞く。
- 仕様書は共通のミス音を各キャラクターのベースへ、なぞり音を詠唱者ベースへ、着弾音を三叉震槌の演出仕様へ追記する。

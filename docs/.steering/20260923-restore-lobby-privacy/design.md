# 設計

- `_apply_lobby_card_layout()` に duel と FFA の両方の完全な座標セットを持たせ、毎回全カード関連ノードの矩形を設定する。
- `refresh_lobby_label()` はローカル slot のみ選択キャラクターの立ち絵を設定し、他 slot は接続済みでも影画像を設定する。
- UIテストは FFA の3枠表示に加え、相手キャラクターの秘匿と FFA から duel へ戻した後の座標復元を検証する。

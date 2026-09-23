# 設計

- `hud.tscn` に相手1・相手2用の算術士倍率ラベルを個別に置き、各HPバー直下の座標をシーン定義で管理する。
- `MatchPrototype` は両ラベルへの参照を保持し、`update_hud()` で各相手の `character_id` と `arithmetic_interference_multiplier` から独立して表示を更新する。
- UIテストで算術士2人・片方のみ・duelの各ケースを確認する。

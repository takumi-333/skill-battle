# 設計

`MatchProtocol._interpolate_entities()` は、各 current エンティティに対して `_matching_entity()` が previous 配列を線形探索する。多数の投射物では O(N^2) となる。

前回配列を走査して、優先順位 `presentation_id` → `projectile_id` → `impact_id` のID別辞書を構築する。current の各エンティティは同じ優先順位で辞書を参照する。IDがない、または辞書に該当しない場合だけ、既存の index と owner_id によるフォールバックを使う。

これにより、IDを持つ通常の投射物・演出の照合は O(N) になる。既存の補間対象プロパティと戻り値の形式は変えない。

テストは、配列順を入れ替えた同一IDの投射物が正しく補間されること、IDなしの既存フォールバックが維持されることを確認する。

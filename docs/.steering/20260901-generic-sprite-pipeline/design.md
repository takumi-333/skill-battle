# 汎用スプライト制作パイプライン — 設計

## データモデル

新規仕様はasset specとanimation specを分離する。

```text
企画書（人間・AI向け）
  ├─ asset spec: canvas、layout、anchor、palette、profile、正規化
  └─ animation spec: clips、variants、frames、placement、timing、events
```

- asset specの`layout.type`は`grid`または`atlas`。gridはcell sizeと列・行IDを持ち、atlasはcanvasだけを持つ。
- animation specは`clips[]`を正本とする。clipは`id`、`loop`、`fps`、`variants[]`、`frames[]`を持つ。variantがないclipは暗黙の`default` variantとして扱う。
- フレームは一意な`id`と`placement`を持つ。placementはgridの`column` / `row` またはatlasの`x` / `y` / `width` / `height`で表す。`duration`と`events`は任意。
- anchorは`feet`、`center`、`none`を扱う。frameの`root`がある場合は常にそれを優先する。
- profileは`character`、`weapon_attack`、`projectile`、`effect`。共通検査はRGBA、canvas、二値alpha、パレット、各配置領域の非空。人物限定の寸法・アンカー・cleanup・停止歩行比はcharacterだけに適用する。

既存の`columns` / `rows` / `foot_anchor`と`frames[].direction` / `phase`の形式は、読込時にgrid layout・character profile・`idle` / `walk` clip・方向variantへ変換する。CLIは`--animation`を追加し、`--motion`を互換エイリアスとして残す。

## 実装

共有モジュール`tools/sprite_pipeline.py`に仕様読込・検証・legacy変換・placement解決を置く。各ツールがそれぞれ独自に方向・行を解釈する状態をなくす。

- `build_sprite.py`: animation specの全フレームを読み、placementの矩形へ配置する。reportにはclip / variant / placementを記録する。
- `validate_sprite.py`: placementごとに共通検査を行い、profile固有検査を条件付きで行う。
- `preview_sprite_animation.py`: clip選択とvariant選択を持つ自己完結HTMLを生成し、各フレームの矩形を再生する。
- `promote_sprite.py`: `--animation`をvalidatorへ引き渡し、`--motion`互換を維持する。
- `extract_sheet_frames.py`: asset specとanimation specを受け、任意矩形を非破壊に展開する。

## 文書構成

新しい`docs/guides/スプライト素材作成ガイドライン/`を正本とする。旧`8方向スプライト素材作成ガイドライン/`は、8方向移動専用の補足と新しい正本への導線に更新する。キャラクターアセット制作ガイドは、移動スプライト固有の節を残しつつ、汎用パイプライン・新仕様への参照を追加する。

## 検証

- 既存8方向motion specを読み、現行プレビューのテストを通す。
- gridを使う無方向16フレームeffectのfixtureでbuild→validate→previewを実行する。
- effect profileがcleanupの分離粒子を許容し、character profileが既存のcleanup検査を維持することを確認する。
- Pythonの全テストを実行し、可能な範囲でGodotをheadless実行して既存素材の読込エラーがないことを確認する。

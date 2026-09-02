# キャラクター画面の実装

## 前提
- ホーム画面のキャラクター画面を押した後に遷移する「キャラクター画面」について実装する
- イメージは基本以下を参照 @docs\ideas\skill_customization_screen_concept_v2.png
## キャラクター画面のできること
- 対象のキャラクター切り替え（キャラクター画面上での切り替えができる機能）
    - イメージ画像の左のバー
- スキルのセット
    - セットしたスキルが対戦・練習で使える
    - 各キャラクターにスキル1, 2, 3がありそれぞれに3 ~ 5個候補がある
    - 候補はこれから順次追加予定なので、スキルごとのエリアでマウススクロール（横にスクロールする）をできるようにしておく

## 画面レイアウト


- 画面上部中央に今選んでいるキャラの名前（各キャラクター専用のロゴを用意する予定）
- 画面一番左にキャラクター選択一覧
    - ここは縦スクロールできるエリア
    - 各キャラの顔の部分だけが、移っているウィンドウ
    - 押すとそのキャラに切り替え
- キャラクターの立ち絵をでかでかと画面中央少し左に表示
- 画面右の上部には、キャラクターの使い方説明
    - 打鍵士は、タイピングの速度で、スキル発動みたいなことを書く
- その下に３スキルのセット画面
    - このエリアはそれぞれマウスで横スクロールできる
- 一番下に、セットしているスキルを見れるのと、ＳＡＶＥボタン
    - ボタンは、UIは固定だから大小とかでアニメーションして押している感を演出
    - SAVEボタンを押したら、そのスキルセットが保存されるだけ。遷移とかはしない。
- 画面左上にホームに戻るボタン
    - キャラクターを選ぶウィンドウの上にかぶらないように配置


## 作成する画像
- 各スキルのアイコン：作成しなくてよい
    - いったんは、@assets\ui\skill_iconsを使う
- 各キャラクターの背景：作成済み
- 各キャラクターの雰囲気に合ったSAVEボタン：作成済み

## 制作規格メモ（2026-09-02）

地下アーケードの設定は使用せず、各キャラクターの個室・工房・研究室などの屋内空間として制作する。レトロ感は、古い家具、機械、照明、素材の擦れた質感で表現する。

### 共通方針

- ダークファンタジーを基調に、キャラクターのテーマカラーを主役にする
- 暗色を70〜80%、テーマカラーとアクセントカラーを20〜30%の目安にする
- 背景にキャラクター、文字、ロゴ、UI、ボタンを描き込まない
- 背景中央〜左側は立ち絵表示用に情報量を抑える
- 背景右側は説明文を重ねるため、暗く低コントラストにする
- SAVEボタン画像には文字を描き込まず、`SAVE` の文字は実装側で表示する
- SAVEボタンは通常状態のベース素材とし、ホバー・押下・無効状態は実装側で表現する

### 制作目標規格

| 素材 | サイズ | 形式 | 備考 |
| --- | --- | --- | --- |
| キャラクター背景 | `1920x1080px`、16:9 | 不透明PNG、sRGB | キャラクター画面の全面背景 |
| キャラクター別SAVEボタン | `1536x384px`、約4:1 | 透過PNG、32bit ARGB | 表示目安 `360x88px`、中央に文字用の余白 |

### 配置済みファイル

| キャラクター | 背景 | SAVEボタン |
| --- | --- | --- |
| 打鍵者 | `assets/ui/character_room/typist_background.png` | `assets/ui/character_room/typist_save_button.png` |
| 算術士 | `assets/ui/character_room/arithmetician_background.png` | `assets/ui/character_room/arithmetician_save_button.png` |
| 詠唱者 | `assets/ui/character_room/chanter_background.png` | `assets/ui/character_room/chanter_save_button.png` |

既存素材は生成時の原寸を保持する。今後追加する素材は、上記の制作目標規格に合わせる。

## ウィンドウ枠素材の追加規格・プロンプト（2026-09-02）

スキル選択欄とキャラクター選択欄に使う枠は、Godotの`NinePatchRect`で上下左右へ変形して使用する。SAVEボタンと同じキャラクター別の色・装飾・質感にそろえる。

### ウィンドウ枠の制作規格

- 画像サイズ：`512x512px`
- 形式：透過PNG、32bit ARGB、sRGB
- 用途：`NinePatchRect`の通常状態用ベース素材
- 9-slice境界：上下左右`128px`を固定領域、中央`256x256px`は透明または低密度の背景領域
- 四隅：装飾を完全に収め、拡大縮小で形が崩れないようにする
- 上下辺：水平方向に繰り返し・伸縮可能な単純な模様
- 左右辺：垂直方向に繰り返し・伸縮可能な単純な模様
- 中央：透明。ゲーム内の文字・立ち絵・スキルアイコンを置くための余白
- 文字、ロゴ、キャラクター、ボタン名、UI記号は描き込まない
- `NinePatchRect`の初期設定目安：`patch_margin = 128px`、`axis_stretch = TILE_FIT`
- キャラクター選択ウィンドウとスキル選択ウィンドウの両方に同じ枠を使い、表示サイズだけを変える

### コピペ用プロンプト

#### 打鍵者：SAVEボタンと一緒に送るプロンプト

```text
Using the attached Typist SAVE button as the exact visual style reference, create a reusable fantasy UI window frame for the Typist character.
Dark fantasy with retro mechanical workshop details: deep forest green, aged brass, gunmetal black, subtle worn metal and old keyboard-machine motifs. Match the attached SAVE button's palette, ornament density, line weight, material, lighting, and handmade retro finish.
Create ONLY a square 9-slice frame asset, no interior panel fill: 512x512 pixels, transparent PNG, 32-bit ARGB, sRGB. The four 128x128 pixel corners must contain complete fixed ornaments. The top and bottom edges must use a simple horizontally stretchable or tileable pattern. The left and right edges must use a simple vertically stretchable or tileable pattern. Keep the central 256x256 area transparent and visually quiet for UI content.
No character, no text, no logo, no SAVE lettering, no icons, no buttons, no scenery, no perspective, no drop shadow extending outside the frame. The frame must remain clean and undistorted when resized to both wide horizontal panels and tall narrow character-selection panels. Front-facing orthographic UI asset, crisp readable silhouette, consistent thickness, game-ready.
```

#### 算術士：SAVEボタンと一緒に送るプロンプト

```text
Using the attached Arithmetician SAVE button as the exact visual style reference, create a reusable fantasy UI window frame for the Arithmetician character.
Dark fantasy with a retro occult study and observatory feeling: deep navy, antique gold, blue-gray metal, ivory highlights, subtle engraved geometry and restrained arcane measurement motifs. Match the attached SAVE button's palette, ornament density, line weight, material, lighting, and handmade retro finish.
Create ONLY a square 9-slice frame asset, no interior panel fill: 512x512 pixels, transparent PNG, 32-bit ARGB, sRGB. The four 128x128 pixel corners must contain complete fixed ornaments. The top and bottom edges must use a simple horizontally stretchable or tileable pattern. The left and right edges must use a simple vertically stretchable or tileable pattern. Keep the central 256x256 area transparent and visually quiet for UI content.
No character, no text, no logo, no SAVE lettering, no icons, no buttons, no scenery, no perspective, no drop shadow extending outside the frame. The frame must remain clean and undistorted when resized to both wide horizontal panels and tall narrow character-selection panels. Front-facing orthographic UI asset, crisp readable silhouette, consistent thickness, game-ready.
```

#### 詠唱者：SAVEボタンと一緒に送るプロンプト

```text
Using the attached Chanter SAVE button as the exact visual style reference, create a reusable fantasy UI window frame for the Chanter character.
Dark fantasy with a retro theatrical dressing-room feeling: deep purple, antique gold, black, pale pink accents, subtle ribbon, crescent, heart, and stage-ornament motifs. Match the attached SAVE button's palette, ornament density, line weight, material, lighting, and handmade retro finish.
Create ONLY a square 9-slice frame asset, no interior panel fill: 512x512 pixels, transparent PNG, 32-bit ARGB, sRGB. The four 128x128 pixel corners must contain complete fixed ornaments. The top and bottom edges must use a simple horizontally stretchable or tileable pattern. The left and right edges must use a simple vertically stretchable or tileable pattern. Keep the central 256x256 area transparent and visually quiet for UI content.
No character, no text, no logo, no SAVE lettering, no icons, no buttons, no scenery, no perspective, no drop shadow extending outside the frame. The frame must remain clean and undistorted when resized to both wide horizontal panels and tall narrow character-selection panels. Front-facing orthographic UI asset, crisp readable silhouette, consistent thickness, game-ready.
```

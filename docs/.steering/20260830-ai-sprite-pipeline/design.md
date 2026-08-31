# AIスプライト生成パイプライン — 設計

## アーキテクチャ概要

AIは候補画像を生成するレンダリング工程に限定する。完成スプライトシートの生成は要求せず、**出力単位は1フレーム、生成コンテキストはシーケンス全体**とする。各フレームは不変のCharacter Master、Direction Reference、Style Reference、motion/pose specを主入力に取る。隣接フレームは、主入力を置き換えず微細な連続性だけを補助する任意の二次入力とする。ゲームが要求する座標、サイズ、透過、パレット、ファイル構造はPythonツールで確定させ、検査を通った出力だけをGodotへ渡す。

```text
世界観・キャラクター設定・制作ガイド
              ↓
asset spec + generation manifest
              ↓
assets/motions/humanoid_walk_8dir.json
（40フレームのmotion spec / Pose Guide）
              ↓
Character Master + Direction Reference + Style Reference + Pose Guide（PRIMARY・不変）
              ↓
Neighboring Frame（SECONDARY・任意）
              ↓
AI renders ONE frame
              ↓
source image（RGBAを前提にしない）
              ↓
alpha extraction / background removal → RGBA normalized frame
              ↓
pixelization → palette quantization → pixel cleanup → anchor normalization
              ↓
raw/<asset-id>/frames/<direction>_<motion>.png × 40
              ↓
build_sprite.py（40枚を正規化・組版） ──→ validated/<asset-id>/sheet.png
              ↓                         ↓
              └──── validate_sprite.py ─┘
                                      ↓ PASS
                        assets/characters/<id>_pixel_8dir.png
                                      ↓
                                   Godot表示
```

生成器の入出力はraw画像とmanifestに限定する。個別ファイルは生成の独立性を意味しないが、フレーム間を参照チェーンにもせず、すべてのフレームを同じ不変の主参照へ接続する。各rawフレームのmanifestには、主参照・二次参照の役割、対応するpose、シーケンスIDを記録する。`build_sprite.py`と`validate_sprite.py`は生成器に依存しないため、将来の参照画像・ポーズ・時間方向制御を持つ生成器へ変更しても置き換え不要とする。

## コンポーネント設計

### 1. アセット仕様 (`assets/specs/<asset-id>.json`)

**責務**:

- 生成後の正規化・検査に必要な機械可読の制約を定義する。
- デザイン契約の要約と、人間レビュー時の確認項目を保持する。

**実装の要点**:

- `canvas`、`cell_size`、`columns`、`rows`、`directions`、`animation_rows`、`foot_anchor`、`palette`、`source_grid`を必須にする。
- 初期値は現行ガイドに合わせてcanvas 512×320、cell 64×64、8列×5行とする。
- 人物の外見条件は完全自動判定しない。`design_contract`として記録し、人間レビューの根拠に使う。

### 2. motion spec (`assets/motions/humanoid_walk_8dir.json`)

**責務**:

- 40フレームの動作を、キャラクターの外見とは独立して先に確定する。

**実装の要点**:

- 各frame IDに`phase`、`direction_deg`、左右の足の状態、`body_bob`、`anchor`、Pose Guideのパスを定義する。
- AIには「歩いている2枚目」を解釈させず、このmotion specで指定したPose Guideを当該キャラクターとしてレンダリングさせる。
- Pose Guideの実体はOpenPose、2D skeleton、Blender render、手描きsilhouetteのいずれも許容する。形式は差し替え可能にする。

### 3. 生成manifest (`assets/manifests/<asset-id>.json`)

**責務**:

- 生成候補の出所と採用判断を追跡可能にする。

**実装の要点**:

- provider/model/version/seed/prompt/reference inputの出所/post-process/human reviewを記録する。
- `sequence_id`、`frame_id`、motion/pose spec、Character Master、Direction Reference、Style Referenceを主参照として記録する。隣接フレームを使う場合は、二次参照として明示的に記録する。
- alphaの由来を`generator`または`postprocess`で記録する。後処理時はmethod、tool version、thresholdなど再現に必要な設定を記録する。
- 権利未確認の第三者画像を参照入力や学習データに使わない。入力は自作・権利確認済み・生成済みのいずれかを明記する。
- secretやAPIキーは書かない。

### 4. 連続フレーム生成器

**責務**:

- 共通の外見・方向・スタイル制約を維持しながら、指定poseのフレーム候補を1枚出力する。

**実装の要点**:

- Character Masterは全方向・全位相で共通かつ不変にする。Direction Referenceは当該方向の見え方を拘束し、Style Referenceはピクセル密度・輪郭・配色の基準にする。これらとPose Guideが主参照である。
- motion/pose specは生成前に定義し、足元と中心の基準座標を含める。AIに歩行の位相やレイアウトを解釈させない。
- 隣接フレーム参照は補助であり、Character Master・Direction Reference・Style Reference・Pose Guideを置き換えない。直前フレームを次フレームの主参照にする参照チェーンは禁止する。次フレームが未生成でも生成手順が変わらない設計にする。
- 生成器が時間方向の一貫性制御を提供する場合は、同一`sequence_id`のフレームを同じ生成コンテキストで扱う。

### 5. フレーム正規化・pixelization・ビルダー

**責務**:

- 個別rawフレームを仕様の40枠へ対応付け、正規化・足元揃え・必要なパレット変換・組版を行い、検査対象の出力を作る。

**実装の要点**:

- `down_idle`、`down_left_walk_01`のような一意のフレームIDで入力を指定する。入力不足・重複・未知のIDは即時失敗とする。
- source imageをRGBA前提にしない。ネイティブ透過出力は保持し、不透明出力には選択したalpha extraction／background removalを適用する。
- `pixelize_frame.py`でpixelization、palette quantization、必要最小限のpixel cleanupを行う。高解像度semantic renderを`NEAREST`だけで64pxに間引いてはならない。
- `NEAREST`は、pixel gridが確定した後にgridを壊さず拡大・縮小する用途に限定する。
- `build_sprite.py`はpixel化済みのRGBA normalized frameをアンカーへ配置し、40枚を組版する。
- 変換前後のサイズ、アンカー移動量、パレット変換数をbuild reportへ出力する。

### 6. バリデーター (`tools/validate_sprite.py`)

**責務**:

- Godotへ昇格可能なハード制約を検査し、失敗を機械・人間の双方が利用可能な診断にする。

**実装の要点**:

- 40件のフレームID、画像形式、寸法、RGBA、各セルの前景、セル境界余白、足元アンカー、許可外色、ファイル名を検査する。
- 各検査はフレーム番号、方向、行、座標、期待値、実測値を出力する。
- alpha maskからbbox、中心X、底辺Y、占有率を測定する。同一`sequence_id`の隣接フレーム間で、bboxサイズ・重心・足元位置・前景変化量が急変した場合は診断する。
- 既存素材の実測を基準に、意図しない拡大縮小・左右のガタつき・足元の浮きをwarningとして出せるようにする。採用可否はループ再生を含む人間レビューで決める。

### 7. 昇格処理 (`tools/promote_sprite.py` またはビルドの明示オプション)

**責務**:

- 検査済み成果物を規約のファイル名で配置する。

**実装の要点**:

- validate成功が確認できない場合は終了する。
- 既存の採用素材を上書きする場合は、事前に差分・manifest・人間レビューを確認できる状態にする。
- 初期導入のパイロットでは既存採用素材を置換せず、別の検証用出力で完結させる。

## データフロー

### 追加キャラクターの停止・歩行シート制作

```text
1. 世界観・キャラクター設定からデザイン契約を作り、asset specへ記録する。
2. `assets/motions/humanoid_walk_8dir.json`で40フレームのmotion specとPose Guideを先に確定する。
3. 不変のCharacter Master、Direction Reference、Style Referenceを採用する。
4. `sequence_id`を方向ごとに作成し、同じ主参照と当該Pose Guideからフレーム候補を**1枚ずつ**出力する。隣接フレームは必要な場合だけ二次参照として渡すが、生成順や採用可否を主導させない。
5. source imageからalpha extraction／background removalを経てRGBA normalized frameを作る。ネイティブ透過出力はその由来をmanifestに記録して保持する。
6. pixelization、palette quantization、pixel cleanup、anchor normalizationを行う。確定後のpixel gridだけを`NEAREST`で扱う。
7. 1枚ごとに前景、向き、足元、固定要素を確認する。不合格なら、同じ不変の主参照・Pose Guide・sequence contextを維持したまま当該フレームだけを再生成または手作業で修正する。
8. build_sprite.pyで採用済み40枚を組版し、validated出力を作る。
9. validate_sprite.pyでハードゲート、bbox、重心、アンカー、フレーム間変化量を確認し、人がループ再生、シルエット、既存スプライトとの並びを確認する。
10. PASSした候補だけをmanifestへ採用記録し、Godot用アセットへ昇格する。
```

## エラーハンドリング戦略

- 仕様JSONの欠損・型不正、画像読込失敗、グリッド不一致、RGBA不正は即時失敗とする。
- 形式違反は非0終了とJSON／テキストの診断を返す。
- 低い占有率、軽微なアンカーずれ、許可外色は設定によりerrorまたはwarningへ切り替えられるようにする。
- 人物の別人化、武器欠落、歩行の不自然さ、IP類似の疑いは自動修正せず、手動レビューへ戻す。

## テスト戦略

### ユニットテスト

- JSON仕様の読込・既定値・不正値拒否。
- RGBA、寸法、40フレーム対応、最近傍縮小、アンカー位置、パレット、bbox・重心・フレーム間変化量の検査。
- 意図的に壊したfixture（RGB画像、フレーム欠落、空セル、セル越境、許可外色、足元ずれ、急なbbox変化）の診断。

### 統合テスト

- 40枚のraw fixtureからbuild→validateを実行し、512×320px RGBAの40セル出力を得る。
- 検査成功後の昇格と、検査失敗時に採用先を変更しないことを確認する。
- Godotを実行できる環境では、採用済みシートを使った8方向の停止・歩行を確認する。

## 依存ライブラリ

- 初期導入はPython 3.10以上とPillowを必須とする。
- OpenCVは占有率・輪郭・時系列指標を追加する段階で導入する。初期ハードゲートには不要とする。
- ComfyUI、Diffusers、ControlNet、IP-Adapter、LoRAは生成器の選択肢であり、このリポジトリの必須依存にはしない。

## ディレクトリ構造

```text
assets/
  characters/                 # Godotが読む採用済み素材
  specs/
    <asset-id>.json
  manifests/
    <asset-id>.json
  generated/
    raw/<asset-id>/frames/
      <direction>_<motion>.png
    validated/<asset-id>/
tools/
  build_sprite.py
  validate_sprite.py
  promote_sprite.py
tests/
  sprite_pipeline/
    fixtures/
    test_build_sprite.py
    test_validate_sprite.py
```

`assets/generated/`、`assets/manifests/`、`assets/motions/`、`assets/specs/`はローカル作業領域とし、生成画像、中間フレーム、候補シート、build／validationレポート、manifest、motion spec、asset specをGit管理しない。各ディレクトリの`.gdignore`によってGodotのスキャン対象からも外す。採用済み素材は`assets/characters/`へ昇格し、正式に残す仕様は`docs/specs/`、生成ツールは`tools/`へ配置する。

## 実装の順序

1. 現行ガイドを補強して、仕様JSON・manifest・ハードゲートを正式な制作規約にする。
2. specの読込、ビルド、検査をfixtureでテスト可能なPythonツールとして実装する。
3. 既存の採用素材を変更しないパイロット用候補で、1フレームずつの生成→フレームレビュー→build→validateを実施する。
4. Godot上の表示確認後に、昇格処理と運用手順を確定する。
5. 1枚ずつの参照生成でも同一性や時系列品質が不足すると判明した場合だけ、ControlNet／IP-Adapter／LoRA／時系列モデルを評価する。

## セキュリティ・権利上の考慮事項

- APIキー、認証情報、個人情報をmanifestやリポジトリへ保存しない。
- モデル、checkpoint、LoRA、参照画像ごとにライセンス・入手元・商用利用可否を記録する。
- 特定の第三者作品・作家を模倣する指示や、権利未確認の画像を参照入力に使わない。
- 人間による類似性レビューを採用工程に残す。

## パフォーマンスと拡張性

- 画像処理はオフラインの制作工程であり、Godotの実行時コストを増やさない。
- specとmanifestを生成器から分離するため、クラウド生成、ローカルGPU、将来の別モデルへ移行できる。
- 攻撃・被弾・エフェクトを追加する場合は、モーション種別ごとにasset specを増やし、既存のビルド・検査ロジックを再利用する。

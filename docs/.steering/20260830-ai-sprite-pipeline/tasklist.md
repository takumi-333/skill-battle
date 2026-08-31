# AIスプライト生成パイプライン — タスクリスト

## フェーズ1: 永続仕様の確定

- [x] `docs/guides/キャラクターアセット制作ガイド.md` に、spec・manifest・raw／validated出力・採用ゲートの運用を追記する
  - [x] 既存の512×320px、64×64px、8列×5行、方向・歩行行の規約を機械可読仕様に対応付ける
  - [x] AI生成、決定論的処理、人間レビューの責務境界を定義する
  - [x] モデル・入力画像・ライセンス・レビューを記録する方針を定義する

- [ ] asset specとmanifestのJSONスキーマおよびサンプルを追加する
  - [ ] 必須フィールドと不正値の扱いを定義する
  - [ ] 40件の個別フレームIDと、シート上の方向・行・列の対応を定義する
  - [ ] 既存キャラクターを変更しないパイロット用のサンプルを作成する

- [x] `assets/motions/humanoid_walk_8dir.json` を作成する
  - [x] 40フレーム全件のphase、direction、足運び、body bob、anchorを定義する
  - [x] OpenPose、2D skeleton、Blender render、手描きsilhouetteを参照できるPose Guideのスキーマを定義する

- [x] 打鍵士の移動スプライトを、既存の採用素材を上書きしないパイロットとして定義する
  - [x] `typist_walk_8dir_pilot` のasset spec・manifest・デザイン契約を作成する
  - [x] 既存の打鍵士スプライトをCharacter MasterおよびDirection Referenceとして記録する
  - [x] 生成候補・正規化済みフレーム・検査済みシートを`assets/generated/`へ分離する

## フェーズ2: ビルドと検査の実装

- [x] Python実行環境とPillowの導入方法をプロジェクトへ記録する
  - [x] 実行可能なPython/Pillow環境を確認し、確認結果をパイロットmanifestへ記録する

- [ ] `tools/build_sprite.py` を実装する
  - [ ] specに従い40枚の個別rawフレームを読み込み、IDとシート上の位置を対応付ける
  - [ ] 最近傍補間、RGBA保持、足元アンカー揃えを実装する
  - [ ] 40枚を8列×5行へ組版する
  - [ ] 指定時のみ厳密パレット変換を実装する
  - [ ] build reportを出力する

- [x] `tools/extract_alpha.py` と `tools/pixelize_frame.py` を実装する
  - [x] ネイティブ透過とpostprocessによるalpha extractionを判定・記録する
  - [x] pixelization、palette quantization、pixel cleanupを実装する
  - [x] `NEAREST`を確定済みpixel gridの保持用途だけに制限する

- [ ] `tools/validate_sprite.py` を実装する
  - [ ] 形式、寸法、RGBA、グリッド、非空セル、セル境界、アンカー、パレット、命名規則を検査する
  - [x] 失敗時にフレーム・方向・行・座標・期待値を出力し、非0で終了する

- [x] `tools/promote_sprite.py` または同等の明示的昇格機能を実装する
  - [x] validate成功がなければ昇格を拒否する
  - [x] 成功時に規約のGodot用ファイル名へ配置する

## フェーズ3: 自動テストとパイロット

- [ ] 正常系と異常系の画像fixtureを追加する
  - [ ] RGBA・正規グリッド・正規アンカーの正常fixtureを用意する
  - [ ] フレーム欠落・フレームID重複、RGB、空セル、越境、許可外色、足元ずれの異常fixtureを用意する

- [ ] build・validate・promoteの自動テストを実装して実行する

- [ ] 打鍵士の移動スプライトでパイロットを実施する
  - [ ] asset spec、manifest、基準画像、40件の個別フレームリストを用意する
  - [ ] 1フレームずつ生成・採用し、不合格フレームだけを差し替える
  - [ ] 40枚の採用済みフレームでbuild→validate→人間レビューを実施する
  - [ ] 検査済み素材をGodotへ昇格し、既存素材と並べて確認する

## フェーズ4: Godot確認と運用確定

- [ ] Godotを起動し、パイロット素材の8方向停止・歩行が正常に表示されることを確認する
- [ ] `docs/guides/キャラクターアセット制作ガイド.md` に実際のコマンド例とレビュー手順を追記する
- [ ] 採用素材のmanifest、検査結果、ライセンス情報を確認する
- [ ] tasklistの全項目完了後、振り返りを記録する

## 現在の打鍵士パイロット結果

- [x] 既存の打鍵士シートを40枚の個別参照フレームに展開し、対照用シートをbuild→validateした
  - [x] `assets/generated/validated/typist_walk_8dir_pilot/control_sheet.png`は512×320px・RGBA・40セル・アンカー揃えで検査通過した
  - [x] 昇格前の`assets/characters/typist_pixel_8dir.png`を`pre_promotion_typist_pixel_8dir.png`へ退避した
- [x] 不変のCharacter Master・Direction Reference・motion specから、8方向の`walk_01`候補を1フレームずつ生成した
  - [x] source imageとalpha/pixelizationの処理結果を`assets/generated/raw/typist_walk_8dir_pilot/`に保存した
  - [x] 40フレームがそろうまで、生成候補を`assets/characters/`へ昇格しないことをmanifestに記録した
- [x] 残り24歩行候補を生成し、32歩行候補と8停止フレームからAI候補シートを組版・検査した
  - [x] `assets/generated/validated/typist_walk_8dir_pilot/ai_candidate_sheet.png`はハードゲートを通過した
  - [x] 生成候補を目視し、フレーム間のハンマー・髪・衣装ディテールの揺れをmanifestへ記録した
- [x] ユーザー判断により40枚の候補をゲーム内比較用として一時的に採用した後、元の採用素材へ復元した
  - [x] 昇格時にvalidateを再実行し、候補を比較用アセットへ配置した
  - [x] `pre_promotion_typist_pixel_8dir.png`から元の`typist_pixel_8dir.png`を復元し、候補を削除せず保存した
  - [x] Godotをheadless起動し、テクスチャ読込時のエラーがないことを確認した

## 将来拡張の判断基準（実装タスクには含めない）

- 同一性不足: 基準画像参照を強化し、ControlNet／IP-Adapterを評価する。
- 同一キャラクターの量産が必要: 権利確認済みデータだけでLoRAを評価する。
- フレーム間のちらつきが残る: 時系列生成モデルをベンチマークで比較する。

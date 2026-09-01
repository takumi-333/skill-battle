# タスクリスト

## フェーズ1: 仕様と共有基盤

- [x] 新しいステアリング文書と既存ツール・ガイドの依存関係を確認する
- [x] asset spec / animation spec / profile / legacy互換を扱う共有モジュールを実装する
- [x] 汎用仕様の正常・異常fixtureを追加する

## フェーズ2: ツール改修

- [x] `build_sprite.py`を任意clip・grid・atlasの組版へ対応させる
- [x] `validate_sprite.py`を共通検査とprofile別検査へ分離する
- [x] `preview_sprite_animation.py`をclip / variant再生へ対応させる
- [x] `promote_sprite.py`と`extract_sheet_frames.py`を新仕様と互換CLIへ対応させる

## フェーズ3: ガイドライン改修

- [x] 汎用スプライト制作ガイドライン、フロー、ツール一覧を新設する
- [x] 旧8方向ガイドを移動スプライトの補足・新正本への導線へ更新する
- [x] キャラクターアセット制作ガイドとアートディレクションを新しい責務境界へ更新する

## フェーズ4: 検証と振り返り

- [x] 新旧仕様のユニット・統合テストを実行する
- [x] Godotをheadless起動して既存素材の読込を確認する（プロジェクトのscanは完了。OSの証明書ストア・Godotユーザー設定の保存警告のみで、プロジェクト素材・スクリプトのエラーはなし）
- [x] tasklistの全項目を確認し、振り返りを記録する

## 実装後の振り返り

実装完了日: 2026-09-01

計画との差分: 既存の8方向移動形式を破壊的に置き換えず、`sprite_pipeline.py`でv2形式へ読み込み時に変換する互換層を追加した。これにより、既存の`--motion`を残したまま、新規制作では`--animation`とclip / variant / eventを使える。

学んだこと: 方向・停止・歩行をシートの行列ではなくanimation specの意味として扱うと、4×4の16フレームeffectと任意矩形atlasを同じ組版・検査・プレビュー処理で扱える。人物用のcleanup・足元・身体寸法をprofileで限定することが、粒子を含む演出素材を安全に扱うために重要だった。

次回への改善提案: 新しい攻撃やeffectをゲームへ採用する際は、Godot側にanimation specのclip・variant・eventを読み取るランタイム層を別タスクで追加し、実際のhit判定・効果音・表示矩形との同期をテストする。

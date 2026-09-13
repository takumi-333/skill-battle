# 設計書

## アーキテクチャ概要

ゲーム判定は既存の `MatchSimulation` を正とし、`MatchPrototype` はローカル対戦でも同じ状態項目・入力制限・UIを扱う。強制課題は対象プレイヤーの通常課題とは別の状態として保持し、既存課題がある場合は保存して一時停止する。

```text
算術士スキル3課題成功
  → MatchSimulation / MatchPrototype が相手の強制算術課題を開始
  → 対象クライアントだけが課題文・入力欄を表示
  → 正解: 強制課題を終了し、保存した元課題を再開
  → 失敗: 元課題を中止、5秒封鎖・75%速度・算術士へ0.5ポイント
  → スナップショットの封鎖状態からHUD鎖と頭上鎖を描画
```

## 状態と入力

- 各プレイヤーへ強制課題・封鎖の残り時間・発動者IDを追加し、ネットワーク同期する。
- 通常課題を保存する必要がある場合、課題データと残り時間を対象プレイヤーに保持する。強制課題のタイマーだけを進める。
- 封鎖中は通常攻撃、small/big/skill3、課題開始・中止入力を拒否する。移動と強制課題の送信だけを許可する。
- 強制課題中・封鎖中へ再度このスキルが成功した場合は不発とし、発動者側のクールダウンは適用する。

## UIとアセット

- `head-lock.png` は `assets/ui/status_icons/arithmetic_equation_domination_lock.png` へ移し、対象のワールド座標上方に表示する。
- `skill-lock.png` は `assets/ui/status_overlays/arithmetic_equation_domination_skill_lock.png` へ移し、HUDの各攻撃・スキルダイヤへ前景オーバーレイとして表示する。

## 追加: スキルアイコン

- 透明PNGを `assets/ui/skill_icons/arithmetician_equation_domination.png` として配置する。
- `MatchPrototype.get_skill_icon()` の算術士・スキル3・候補2だけを新アセットへ接続する。候補外の未実装スキル用ロックアイコンは変更しない。

## 追加: 封鎖オーバーレイのシーン編集

- `skill_diamond_small.tscn`、`skill_diamond_medium.tscn`、`skill_diamond_large.tscn` に `EquationDominationLockOverlay` の `TextureRect` を配置する。
- オーバーレイはフレームより前面の `z_index = 4` とし、通常は非表示にする。実行時スクリプトは表示・非表示だけを更新し、位置やサイズを上書きしない。
- 各ダイヤシーンのルートにエディタプレビュー用の公開プロパティを持たせ、鎖を表示したまま調整できるようにする。
- 固定HUDの枠位置は `hud.tscn` を使い、実行時は封鎖状態だけを更新する。画像は入力を遮らない。

## 検証方針

- ヘッドレス起動でスクリプト・シーンのパースを検証する。
- ローカル試合とサーバーシミュレーションのテストを追加または更新し、正解・失敗・入力封鎖・ポイント加算を確認する。
- 実行できる環境でGodotを起動して、鎖画像のHUDと頭上の重なりを確認する。

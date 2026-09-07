# 設計

## 構成

`home_screen.tscn` に設定ボタンとモーダル部品を定義し、`MatchPrototype` が表示制御・保存・通信の接続を担う。

```text
Home/SettingsButton -> MatchPrototype.open_user_settings()
Home/SettingsModal -> save_user_settings() -> user://settings.cfg
                                        -> dedicated loadout event
Dedicated server -> MatchSimulation player.name -> snapshot
snapshot -> lobby / result labels
```

## 実装方針

- モーダルはホーム画面の子 `Control` とし、全面の `Dimmer` と操作を止める `Panel` を持たせる。
- アイコン用 `TextureRect` は入力を透過し、上に重ねる `Button` のみがクリックを受け取る。
- ユーザー名の保存・復元は `ConfigFile` に限定し、空白を除去してから 20 文字に制限する。
- 専用サーバーの `loadout` payload に `display_name` を追加する。プロトコルで型・空白・最大長を検証し、シミュレーションの `player.name` に反映する。
- 再戦時も名前を残すため、セッションのロードアウト保存対象へ `display_name` を加える。
- ローカル／旧ホスト対戦では各ローカル選択時に設定済み名をプレイヤー辞書へ適用する。
- サーバーのプレイヤー状態に `has_display_name` を持たせ、初期キャラクター名を対戦相手のユーザー名として誤表示しない。
- ロビー表示はキャラクター選択とユーザー名を別の表示値として組み立て、リザルトはユーザー名専用の取得関数を通す。

## 検証方針

- 通信プロトコルとシミュレーションのテストに名前の検証・同期を追加する。
- Godot のヘッドレステストを実行後、短時間のプロジェクト起動ログでパースエラーを確認する。

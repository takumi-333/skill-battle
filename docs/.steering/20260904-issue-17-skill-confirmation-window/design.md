# 設計

## UI構成

`scenes/ui/character_screen.tscn` の末尾に、非表示の `SkillDetailOverlay` を追加する。

- 全画面の暗幕 (`ColorRect`)
- 画面の約9割を覆うキャラクター固有フレーム付きパネル
- 左上の大きなアイコン
- 右側のスキル名・説明ラベル
- 下部の閉じる／セットボタンと背面素材用 `TextureRect`

レイアウトはシーンに固定し、スクリプトは `visible`、テキスト、アイコン、フレーム、ボタン素材、テーマ色を更新する。

## 入力と状態

- `character_skill_detail_open`、`character_skill_detail_slot`、`character_skill_detail_candidate` を一時状態として保持する。
- スキルボタンの接続先を `open_skill_detail()` に変更する。
- `open_skill_detail()` はスキル確認専用音を再生し、詳細を更新してオーバーレイを表示する。
- 共通の `connect_existing_ui_clicks()` がモーダルのボタンに通常クリック音を追加しないよう、専用ボタンは接続除外メタデータを付ける。
- 閉じる・セット後、選択状態と画面表示を更新する。セット前の既存選択は維持する。

## 表示データ

スキル名と説明はキャラクター／スロット／候補の組み合わせから返す。未実装候補にも確認可能な「未実装」表示を用意し、セット操作は既存の選択更新ロジックを利用する。

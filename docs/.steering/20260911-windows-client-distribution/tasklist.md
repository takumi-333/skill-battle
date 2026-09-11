# タスクリスト

## フェーズ1: 調査と計画

- [x] 既存の公開運用、クライアント設定保存、Windows export の不足を確認する
- [x] 配布物に含めるものと共有しない秘密値を設計する

## フェーズ2: 実装

- [x] Windows Client の Godot release export preset を追加する
- [x] ZIP 配布物を生成する PowerShell ビルドスクリプトを追加する
- [x] ホストが招待情報を安全に取り出す PowerShell スクリプトを追加する
- [x] ホスト・友人向けの配布と対戦手順書を追加する
- [x] release 成果物を Git 管理対象外にする

## フェーズ3: 検証

- [x] Windows Client release export を実行し、ZIP と実行ファイルを確認する
- [x] Godot の headless 起動確認を実行する
- [x] 既存のロビー UI テストを実行する
- [x] 作業ツリーと、配布物に秘密値が含まれないことを確認する

## 実装後の振り返り

### 実施日

2026-09-11

### 結果

- `build-client-release.ps1` により `build/releases/SkillBattle-Windows-x64-20260911-040844.zip` を生成し、内容が `SkillBattle.exe` と `START_HERE.txt` のみであることを確認した。
- エクスポート済み `SkillBattle.exe --headless --quit-after 2`、`godot --headless --path . --editor --quit`、`tests/network/lobby_ready_ui_test.gd` はすべて終了コード 0 で完了した。
- PowerShell の 2 スクリプトは構文解析を通過し、release 出力は `/build/` の Git ignore 対象であることを確認した。
- 実行環境の `user://` と証明書ストアへの書込み制限に由来する Godot 警告は出たが、export・クライアント起動・ロビー UI テストの失敗はなかった。

### 学び

- Godot の export 終了直後は成果物のファイルシステム反映が遅れる環境があるため、ビルドスクリプトは短い待機で実行ファイルの生成を確認する必要がある。
- 公開 URL と shared invite token はクライアントに埋め込まず、ZIP と別チャネルで共有すれば配布物の再利用・転送時に秘密値を含めずに済む。

### 次回への改善

- 実際に友人へ配布する前に、別回線・別 Windows ユーザーで URL/token の初回設定、ルーム作成、一覧参加、試合、停止後の接続失敗表示までを 1 回通し確認する。

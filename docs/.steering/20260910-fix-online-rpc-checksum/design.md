# 設計

専用サーバーの `MatchPrototype` ノードは `dedicated_server.gd` を使用し、クライアント側は `match_prototype.gd` を使用する。Godot の RPC ノード checksum は同じノードパスの RPC 定義集合を比較するため、クライアントにのみ存在する受信専用 RPC の空実装を専用サーバーにも追加する。

これにより RPC メソッド ID のずれを防ぎ、`submit_match_input` に別 RPC の bool 引数が Dictionary として渡される状態を解消する。変更後は既存のネットワークシミュレーションテストとヘッドレス起動を実行する。

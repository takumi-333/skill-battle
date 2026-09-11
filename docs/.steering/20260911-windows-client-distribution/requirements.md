# 要求事項

## 対象

- Godot や開発ツールを導入していない Windows PC で起動できる、x86_64 のゲームクライアントを再現可能に生成できること。
- 配布物に Lobby URL、招待アクセストークン、ホストの `public.env`、管理トークン、内部トークンを埋め込まないこと。
- 友人が受け取る情報を Lobby の HTTPS URL と shared invite token のみに限定し、ゲームの設定画面で保存できる既存の導線を明記すること。
- ホストが公開 Lobby、Gateway、Dedicated Server、Funnel、playit.gg を安全な順序で起動・停止し、クライアントを配布して 2 人対戦を始められる手順を提供すること。
- ビルドの完了と Godot プロジェクトの起動可能性を確認すること。

## 対象外

- playit.gg や Tailscale のアカウント作成・トンネル契約の自動化。
- Windows コード署名、インストーラー、アップデーターの提供。
- shared invite token を参加者ごとに発行する仕組み。

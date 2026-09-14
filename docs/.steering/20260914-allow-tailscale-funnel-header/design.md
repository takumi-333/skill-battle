# 設計

`tailscale-funnel-request` を、既存の Tailscale/Funnel 由来メタデータ用 allowlist に追加する。Gateway は許可したプロキシメタデータを上流へ再構成しないため、値を信頼・転送しない。

既存の Gateway テストの正規リクエストにこのヘッダーを加え、通過することと上流ヘッダーに含まれないことを検証する。

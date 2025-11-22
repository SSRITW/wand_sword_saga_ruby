# Gateway (API Gateway)

Gatewayはゲームサービスの入口であり、**Ruby on Rails** に基づいて構築されています。

主にクライアントからのHTTPリクエストを処理し、(heartbeatとトークン認証プロトコルを除く)ソケットリクエストをGame Serverへ転送する役割を担います。

## 主要パッケージ説明

*   **`app/controllers`**: HTTP API ハンドル層
*   **`app/services`**: サービス層
    *   `account_service.rb`: アカウント検証、Token 生成など
*   **`app/models`**: DB構造

## 環境依存

*   **Ruby**: `~> 3.x`
*   **Rails**: `~> 8.1.1`
*   **MySQL**: `~> 0.5`
*   **Redis**: ログイン**Token**の保存と、プレイヤー情報の**キャッシュ**に利用されます。

## インストール手順

1.  **コードをクローンする**

2.  **依存Gemのインストール**
    ```bash
    bundle install
    ```

3.  **データベース設定**
    `config/database.yml`を設定し、以下を実行：
    ```bash
    rails db:create
    rails db:migrate
    ```

## 設定説明

環境変数または`.env`ファイルで設定してください：

*   `LOGIN_TOKEN_VALID_TIME`: ログインTokenの有効期限（秒）、デフォルトは300秒。
*   `REDIS_URL`: Redis接続アドレス。

## 起動方法

Railsの標準コマンドで起動します。

```bash
rails server
```

デフォルトのリスニングポートは `3000` です。

## APIの使用例

### アカウントログイン

**APIエンドポイント**: `POST /api/account/login`

**リクエストパラメーター**:
*   `account_name`: (String) アカウント名
*   `platform_id`: (Integer) プラットフォーム ID (0: Guest, 1: X, 2: Facebook, 3: Google)
*   `platform_type`: (Integer) 1: iOS, 2: Android

**リクエスト例**:
```bash
    curl -X POST http://localhost:3000/api/account/login \
      -H "Content-Type: application/json" \
      -d '{"account_name": "test_user", "platform_id": 0, "platform_type": 1}'
```

**成功のレスポンス**:
```json
{
  "code": 1,
  "token": "generated_token_string...",
  "player_info": [...]
}
```

## TODO / 今後の改善計画

*   **gRPC クライアントの多重化（Multiplexing）改修**
    *   **現在の課題**:
        *   現在、プレイヤー接続ごとに新しい `GameServerClient` インスタンスを作成しており、それぞれが2つのスレッド（リクエスト送信とレスポンス受信）を起動しています。1000人のプレイヤーがいる場合、2000のスレッドが必要となり、リソース消費が激しいです。
    *   **計画**:
        1.  `msg.proto` を修正し、`G2G_Message` に `client_id` を含める。
        2.  `GameServerClient` をシングルトン（または共有インスタンス）に変更し、GameServer への gRPC ストリームを1本（または少数）のみ維持する。
        3.  受信したメッセージを `client_id` に基づいて正しい `ClientConnection` にルーティングする。
    *   **目標**:
        *   スレッド使用量を `2 * N` から `2 * M`（Nはプレイヤー数、MはGameServer数）に削減し、スケーラビリティを大幅に向上させる。

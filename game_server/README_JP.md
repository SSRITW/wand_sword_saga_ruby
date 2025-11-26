# Game Server (ゲームサーバー)

**Ruby on Rails** と **gRPC**に基づいて構築したゲームサーバーです。ゲームのコア機能処理を担当し、gRPC経由でGatewayと通信することで、クライアントと繋がります。

## 主要パッケージ説明

*   **`app/grpc`**: gRPCハンドルとサービス層
    *   `services/`: サービス層
    *   `handlers/`: ハンドル層
*   **`app/models`**: DB構造
*   **`config/initializers/grpc_service.rb`**: gRPCサーバーの起動設定スクリプト。Rails初期化後にgRPCを起動します。

## 環境依存

*   **Ruby**: `~> 3.x` (詳細は `.ruby-version`)
*   **Rails**: `~> 8.1.1`
*   **MySQL**: `~> 0.5`
*   **Redis**: キャッシュ・サーバー間の**状態同期**に利用されます。
*   **Protobuf**: Google Protocol Buffers

## インストール手順

1. **Gemのインストール**
    ```bash
    bundle install
    ```

2.  **データベース設定**
    `config/database.yml` にデータベース接続情報を設定した後、以下のコマンドを実行してください。
    ```bash
    rails db:create
    rails db:migrate
    ```

## 設定説明

主に環境変数で設定を行います（`.env` ファイルの使用を推奨）：

*   `GAME_SERVER_ID`: ゲームサーバー ID (例: `1001`)
*   `GRPC_PORT`: gRPCのリッスンポート(例: `127.0.0.1:50051`)
*   `GRPC_POOL_SIZE`: gRPC スレッドプールサイズ
*   `REDIS_URL`: Redis接続アドレス

## 起動方法

Railsの標準コマンドで起動します。

```bash
rails server
```

以下のログで、gRPCサービスが起動したことを確認できます。

`gRPC Server starting on 127.0.0.1:50051`


## TODO
* ~~アイテム　モジュール~~
* ショップ　モジュール
* 外部から接続を閉じる方法。（gRPCの接続方式を修正した後に追加する必要がある）
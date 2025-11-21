# Game Server (ゲームサーバー　游戏服务器)

**Ruby on Rails** と **gRPC**を基ついて構築したゲームサーバー。ゲームのコア機能処理を担当し、gRPCの経由でGatewayとの通信により、クライアントと繋がる</br>
基于 **Ruby on Rails** 和 **gRPC** 构建的游戏服务器。负责处理核心游戏逻辑，并通过 gRPC 与 Gateway 进行通信，进而实现与客户端通讯。

## 主要パッケージ説明 / 主要功能包说明

*   **`app/grpc`**: gRPCハンドルとサービス層 / gRPC 服务层和处理器
    *   `services/`: サービス層
    *   `handlers/`: ハンドル層
*   **`app/models`**: DB構造
*   **`config/initializers/grpc_service.rb`**: gRPCサーバーの起動設定スクリプト、Rails初期化してから、gRPCを起動する</br>__________________________________gRPC的启动配置脚本。在 Rails 初始化完成后启动 gRPC。

## 環境依存 / 环境依赖

*   **Ruby**: `~> 3.x` (詳細 `.ruby-version`)
*   **Rails**: `~> 8.1.1`
*   **MySQL**: `~> 0.5` 
*   **Redis**: キャッシュ・サーバー間の**状態同期**に利用される。 / 用于缓存和服务器状态同步
*   **Protobuf**: Google Protocol Buffers 

##  インストール手順 / 安装步骤

1. **Gemのインストール / 安装依赖Gem**
    ```bash
    bundle install
    ```

2.  **データベース設定 / 数据库设置**</br>
    config/database.yml にデータベース接続情報を設定した後、以下のコマンドを実行</br>
    配置 `config/database.yml` 中的数据库连接信息，然后运行：
    ```bash
    rails db:create
    rails db:migrate
    ```

## 設定説明 / 配置说明
主に環境変数で設定を行う
主要通过环境变量进行配置（推荐使用 `.env` 文件）：

*   `GAME_SERVER_ID`: ゲームサーバー ID (例: `1001`)
*   `GRPC_PORT`: gRPCのリッスンポート(例: `127.0.0.1:50051`)
*   `GRPC_POOL_SIZE`: gRPC スレッドプールサイズ / gRPC 线程池大小
*   `REDIS_URL`: Redis接続アドレス / Redis 连接地址

## 起動方法 / 启动方法

Railsの標準コマンドで起動</br>使用 Rails 标准命令启动。

```bash
　rails server
```
以下のログで、gRPCサービスが起動を確認できる。</br>
看到以下的日志，表明 gRPC 服务已经启动：</br>

`gRPC Server starting on 127.0.0.1:50051`

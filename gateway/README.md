# Gateway (API 网关)

Gatewayはゲームサビースの入口、 **Ruby on Rails** を基ついて構築した。<br>
Gateway 是整个游戏系统的入口，基于 **Ruby on Rails** 构建。<br>

主にクライアントからのHTTPリクエストを処理し、(heartbeatとトークン認証プロトコルを除く)ソケットリクエストをGame Serverへ転送する役割を担う。<br>
主要负责处理客户端的 HTTP 请求，并将socket请求（heartbeat和验证token的协议除外）转发给Game Server。

## 主要パッケージ説明 / 主要功能包说明

*   **`app/controllers`**: HTTP API ハンドル層
*   **`app/services`**: サビース層
    *   `account_service.rb`: アカウント検証、Token 生成など
*   **`app/models`**: DB構造

## 環境依存 / 环境依赖

*   **Ruby**: `~> 3.x`
*   **Rails**: `~> 8.1.1`
*   **MySQL**: `~> 0.5` 
*   **Redis**: ログイン**Token**の保存と、プレイヤー情報の**キャッシュ**に利用される。

##  インストール手順 / 安装步骤

1.  **克隆代码库**

2.  **安装依赖 Gem**
    ```bash
    bundle install
    ```

3.  **数据库设置**
    配置 `config/database.yml`，然后运行：
    ```bash
    rails db:create
    rails db:migrate
    ```

## 設定説明 / 配置说明

请通过环境变量或 `.env` 文件进行配置：

*   `LOGIN_TOKEN_VALID_TIME`: 登录 Token 的有效期（秒），默认 300 秒。
*   `REDIS_URL`: Redis 连接地址。

## 起動方法 / 启动方法

Railsの標準コマンドで起動</br>使用 Rails 标准命令启动。

```bash
　rails server
```

默认监听端口为 `3000`。

## APIの使用例 / API使用示例

### アカウントログイン / 账号登录

**APIエンドポイント**: `POST /api/account/login`

**リクエストパラメーター / 请求参数**:
*   `account_name`: (String) アカウント名 / 账号名称
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

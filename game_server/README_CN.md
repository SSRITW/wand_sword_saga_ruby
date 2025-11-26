# Game Server (游戏服务器)

基于 **Ruby on Rails** 和 **gRPC** 构建的游戏服务器。负责处理核心游戏逻辑，并通过 gRPC 与 Gateway 进行通信，进而实现与客户端通讯。

## 主要功能包说明

*   **`app/grpc`**: gRPC 服务层和处理器
    *   `services/`: 服务层
    *   `handlers/`: 处理器层
*   **`app/models`**: DB结构
*   **`config/initializers/grpc_service.rb`**: gRPC的启动配置脚本。在 Rails 初始化完成后启动 gRPC。

## 环境依赖

*   **Ruby**: `~> 3.x` (详见 `.ruby-version`)
*   **Rails**: `~> 8.1.1`
*   **MySQL**: `~> 0.5`
*   **Redis**: 用于缓存和服务器状态同步
*   **Protobuf**: Google Protocol Buffers

## 安装步骤

1. **安装依赖Gem**
    ```bash
    bundle install
    ```

2.  **数据库设置**
    配置 `config/database.yml` 中的数据库连接信息，然后运行：
    ```bash
    rails db:create
    rails db:migrate
    ```

## 配置说明

主要通过环境变量进行配置（推荐使用 `.env` 文件）：

*   `GAME_SERVER_ID`: 游戏服务器 ID (例: `1001`)
*   `GRPC_PORT`: gRPC 监听端口 (例: `127.0.0.1:50051`)
*   `GRPC_POOL_SIZE`: gRPC 线程池大小
*   `REDIS_URL`: Redis 连接地址

## 启动方法

使用 Rails 标准命令启动。

```bash
rails server
```

看到以下的日志，表明 gRPC 服务已经启动：

`gRPC Server starting on 127.0.0.1:50051`


## TODO 
* ~~道具模块~~
* 商店模块
* 外部关闭连接的方法。（需要在修改了gRPC的链接方式后再增加）
# Wand Sword Saga - Game Server

## 概要 / Overview

这是一个为了学习Ruby和Ruby on Rails的个人游戏服务端项目。

> **Note**
> 这是我第一次尝试使用日语注释的项目。担心表达不准确的时候，我会使用中日双语注释。

## パッケージ説明 / 包说明
*   **`game_server/`**: 游戏核心功能
*   **`gateway/`**: 账号校验和验证转发客户端的消息
*   **`protos/`**: game_server和gateway公用的协议和生成脚本

## 想实现的架构 / Architecture
```mermaid
sequenceDiagram
    participant Client as Game Client
    participant Gateway as Gateway
    participant GS1 as Game Server 1
    participant GS as Game Server.....
    participant GS2 as Game Server n


    Note over Client,GS2: 1. 用户登录认证 / Login Authentication Phase
    Client->>Gateway: 发送认证消息(http)
    Gateway-->>Client: 认证成功，返回加密后的账号id

    Note over Client,GS2: 2. 选择游戏服务器 / Server Selection Phase
    Gateway->>Client: 返回可用服务器列表
    Client-->>Gateway: 选择游戏服务器

    Note over Client,GS2: 3. 建立游戏连接 / Game Connection Phase
    Client->>Gateway: TCP Socket 连接
    Gateway-->>Client: 确认连接
    Client->>Gateway: 发送加密后的账号id
    Gateway-->>Client: 验证账号的合法性成功
    Gateway->>GS1: 建立 gRPC 双向流
    GS1-->>Gateway: 确认连接
    Gateway->>Client: 连接成功

    Note over Client,GS2: 4. 消息传递 / Message Relay Phase
    rect rgb(200, 220, 240)
        Note right of Client: 客户端 → 游戏服务器
        Client->>Gateway: 发送游戏消息
        Gateway->>GS1: 转发消息(gRPC Stream)
        GS1->>Gateway: 响应消息(gRPC Stream)
        Gateway->>Client: 转发响应
    end

    rect rgb(240, 220, 200)
        Note right of GS: 客户端 ← 游戏服务器 (推送)
        GS1->>Gateway: 主动推送消息 (gRPC Stream)
        Gateway->>Client: 转发推送
    end

    Note over Client,GS2: 5. 断开连接 / Disconnection Phase
    Client->>Gateway: 断开 Socket
    Gateway->>GS1: 关闭 gRPC 流
```

## ライセンス / License

此项目仅供个人学习使用。

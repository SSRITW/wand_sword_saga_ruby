# Wand Sword Saga - Game Server

## 概要 / Overview

これはRubyとRuby on Railsを勉強するための個人的なゲームサーバープロジェクトです。  
这是一个为了学习Ruby和Ruby on Rails的个人游戏服务端项目。

> **Note**<br>
> これは初めて日本語でコメントするプロジェクトです。 表現がうまく伝わっているか心配な時は中国語と日本語の2つの言語でコメントします。  
> 这是我第一次尝试使用日语注释的项目。担心表达不准确的时候，我会使用中日双语注释。
> 
## 想实现的架构 / 実現したいアーキテクチャ / Architecture
```mermaid
sequenceDiagram
    participant Client as Game Client
    participant Gateway as Gateway
    participant GS1 as Game Server 1
    participant GS as Game Server.....
    participant GS2 as Game Server n


    Note over Client,GS2: 1. 用户登录认证 / ユーザーログイン認証 / login Authentication Phase
    Client->>Gateway: 发送认证消息(http) <br> 認証token送信 (http)
    Gateway-->>Client: 认证成功，返回加密后的账号id <br> 認証成功、暗号化したaccountIdを戻る

    Note over Client,GS2: 2. 选择游戏服务器 / ゲームサーバー選択 / Server Selection Phase
    Gateway->>Client: 返回可用服务器列表 <br> 可用ゲームサーバーのリストを戻る
    Client-->>Gateway: 选择游戏服务器 <br> ゲームサーバーを選ぶ

    Note over Client,GS2: 3. 建立游戏连接 / ゲームサーバーと接続 / Game Connection Phase
    Client->>Gateway: TCP Socket 连接 <br>TCP Socketを接続 
    Gateway-->>Client: 确认连接 <br> 接続確立
    Client->>Gateway: 发送加密后的账号id <br>　暗号化したaccountIdを送信
    Gateway-->>Client: 验证账号的合法性成功 <br> accountIdの正当性を検証成功
    Gateway->>GS1: 建立 gRPC 双向流 <br> gRPC 双方向ストリーミング接続 
    GS1-->>Gateway: 确认连接 <br> 接続確立
    Gateway->>Client: 连接成功 <br> 接続成功

    Note over Client,GS2: 4. 消息传递 / メッセージ送受信 / Message Relay Phase
    rect rgb(200, 220, 240)
        Note right of Client: 客户端 → 游戏服务器<br> Client →  GameServer
        Client->>Gateway: 发送游戏消息 <br> ゲームメッセージ 送信
        Gateway->>GS1: 转发消息(gRPC Stream) <br> メッセージ転送 (gRPC Stream)
        GS1->>Gateway: 响应消息(gRPC Stream) <br> 応答メッセージ (gRPC Stream)
        Gateway->>Client: 转发响应 <br> 応答メッセージ転送 
    end

    rect rgb(240, 220, 200)
        Note right of GS: 客户端 ← 游戏服务器 (推送)<br> Client ← GameServert(プッシュ通知)
        GS1->>Gateway: 主动推送消息 (gRPC Stream)<br>能動プッシュ(gRPC Stream)
        Gateway->>Client: 转发推送<br>プッシュ転送
    end

    Note over Client,GS2: 5. 断开连接 /  接続を切断 / Disconnection Phase
    Client->>Gateway: 断开 Socket<br>Socketを切断
    Gateway->>GS1: 关闭 gRPC 流<br>gRPCストリームを閉じる
```

## ライセンス / License

このプロジェクトは個人学習用です。<br>
此项目仅供个人学习使用。
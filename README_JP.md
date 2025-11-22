# Wand Sword Saga - Game Server

## 概要

これはRubyとRuby on Railsを勉強するための個人的なゲームサーバープロジェクトです。

> **Note**
> これは初めて日本語でコメントするプロジェクトです。 表現がうまく伝わっているか心配な時は中国語と日本語の2つの言語でコメントします。

## パッケージ説明
*   **`game_server/`**: ゲームのコア機能実現
*   **`gateway/`**: ログイン認証とクライアントメッセージの検証・転送
*   **`protos/`**: game_serverとgateway公用のプロトコル＆生成スクリプト

## アーキテクチャ
```mermaid
sequenceDiagram
    participant Client as Game Client
    participant Gateway as Gateway
    participant GS1 as Game Server 1
    participant GS as Game Server.....
    participant GS2 as Game Server n


    Note over Client,GS2: 1. ユーザーログイン認証 / Login Authentication Phase
    Client->>Gateway: 認証token送信 (http)
    Gateway-->>Client: 認証成功、暗号化したaccountIdを戻る

    Note over Client,GS2: 2. ゲームサーバー選択 / Server Selection Phase
    Gateway->>Client: 可用ゲームサーバーのリストを戻る
    Client-->>Gateway: ゲームサーバーを選ぶ

    Note over Client,GS2: 3. ゲームサーバーと接続 / Game Connection Phase
    Client->>Gateway: TCP Socketを接続 
    Gateway-->>Client: 接続確立
    Client->>Gateway: 暗号化したaccountIdを送信
    Gateway-->>Client: accountIdの正当性を検証成功
    Gateway->>GS1: gRPC 双方向ストリーミング接続 
    GS1-->>Gateway: 接続確立
    Gateway->>Client: 接続成功

    Note over Client,GS2: 4. メッセージ送受信 / Message Relay Phase
    rect rgb(200, 220, 240)
        Note right of Client: Client →  GameServer
        Client->>Gateway: ゲームメッセージ 送信
        Gateway->>GS1: メッセージ転送 (gRPC Stream)
        GS1->>Gateway: 応答メッセージ (gRPC Stream)
        Gateway->>Client: 応答メッセージ転送 
    end

    rect rgb(240, 220, 200)
        Note right of GS: Client ← GameServert(プッシュ通知)
        GS1->>Gateway: 能動プッシュ(gRPC Stream)
        Gateway->>Client: プッシュ転送
    end

    Note over Client,GS2: 5. 接続を切断 / Disconnection Phase
    Client->>Gateway: Socketを切断
    Gateway->>GS1: gRPCストリームを閉じる
```

## ライセンス

このプロジェクトは個人学習用です。

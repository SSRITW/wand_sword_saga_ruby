require 'grpc'
require_relative '../protos/msg_services_pb'
require_relative 'session_context'

module GrpcService
  class PlayerSessionService < Protocol::GameServerService::Service
    def initialize(handlers: {})
      # sessionsの構造:　{ account_id: , player_id: ,created_at: ,last_active_at:}
      @sessions = Concurrent::Hash.new
      # userIdとsessionのマッピング：｛player_id:session_id｝
      @user_session_map = Concurrent::Hash.new
      @logger = Rails.logger
      @handlers = handlers
    end

    # Gateway通过这个双向流连接到GameServer
    # Gatewayを通じてGameServerに双方向ストリームで接続
    # 一个流 = 一个玩家会话 / 1つのストリーム = 1つのプレイヤーセッション
    def player_session(gateway_messages)
      session_id = SecureRandom.uuid

      # セッションデータ初期化
      # 初始化会话数据
      @sessions[session_id] = {
        created_at: Time.now,
        last_active_at: Time.now,
        player_id: nil,  # 验证后填充
        account_id: nil
      }

      # 送信キュー
      # 发送队列
      output_queue = Queue.new

      # 入力処理スレッド
      # 输入处理线程
      Thread.new do
        begin
          @logger.info "New gRPC stream connection: #{session_id}"

          gateway_messages.each do |msg|
            handle_gateway_message(msg, session_id, output_queue)
          end
        rescue StandardError => e
          @logger.error "Session #{session_id} input error: #{e.message}"
          @logger.error e.backtrace.join("\n")
        ensure
          # 入力終了またはエラー時にキューに停止信号を送る
          # 输入结束或出错时向队列发送停止信号
          output_queue << :stop
        end
      end

      # 出力Enumerator
      # 输出Enumerator
      Enumerator.new do |yielder|
        begin
          loop do
            msg = output_queue.pop
            break if msg == :stop
            yielder << msg
          end
        ensure
          cleanup_session(session_id)
        end
      end
    end

    private

    def handle_gateway_message(msg, session_id, yielder)
      protocol_id = msg.protocol_id
      data = msg.data

      @logger.debug "Received: protocol_id=#{protocol_id}, size=#{data.bytesize}"

      # ハンドラー検索（O(1) Hash検索）
      # 1. 查找处理器（O(1) Hash查找）
      handler = @handlers[protocol_id]

      unless handler
        @logger.warn "No handler for protocol_id: #{protocol_id}"
        return
      end

      # メッセージクラス取得とデシリアライズ
      # 2. 获取消息类并反序列化
      message_class = SocketServer::ProtocolTypes.get_class(protocol_id)
      message = message_class.decode(data)


      session_data = @sessions[session_id]
      # SessionContext作成
      # 创建 SessionContext 对象
      context = SessionContext.new(session_id, yielder, session_data, @logger)

      # ハンドラー呼び出し
      # 3. 调用处理器
      handler.call(message, context)

    rescue Google::Protobuf::ParseError => e
      @logger.error "Failed to parse protocol_id=#{protocol_id}: #{e.message}"
    rescue StandardError => e
      @logger.error "Error handling protocol_id=#{protocol_id}: #{e.message}"
      @logger.error e.backtrace.join("\n")
    end

    def cleanup_session(session_id)
      session_data = @sessions[session_id]
      if session_data && session_data[:player_id]
        player_id = session_data[:player_id]

        # 清理 player_data 中的 context 引用，避免内存泄漏
        player_data = $player_datas[player_id]
        if player_data
          player_data.context = nil
        end

        # 调用 PlayerService.offline 进行玩家下线处理
        PlayerService.offline(player_id)

        # 清理 user_session_map
        @user_session_map.delete(player_id)

        @logger.info "Player offline: player_id=#{player_id}, session=#{session_id}"
      end

      @sessions.delete(session_id)
      @logger.info "Session cleaned up: #{session_id}"
    end
  end
end

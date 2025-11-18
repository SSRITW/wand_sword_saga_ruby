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

      Enumerator.new do |yielder|
        begin
          @logger.info "New gRPC stream connection: #{session_id}"

          gateway_messages.each do |msg|
            handle_gateway_message(msg, session_id, yielder)
          end
        rescue StandardError => e
          @logger.error "Session #{session_id} error: #{e.message}"
          @logger.error e.backtrace.join("\n")
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

      # ハンドラー呼び出し
      # 3. 调用处理器
      handler.call(message, session_id, yielder)

    rescue Google::Protobuf::ParseError => e
      @logger.error "Failed to parse protocol_id=#{protocol_id}: #{e.message}"
    rescue StandardError => e
      @logger.error "Error handling protocol_id=#{protocol_id}: #{e.message}"
      @logger.error e.backtrace.join("\n")
    end

    def cleanup_session(session_id)
      @sessions.delete(session_id)
      @logger.info "Session cleaned up: #{session_id}"
    end
  end
end

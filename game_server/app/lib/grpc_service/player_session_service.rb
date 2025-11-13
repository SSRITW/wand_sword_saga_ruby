require 'grpc'
require_relative '../protos/msg_services_pb'

module GrpcService
  class PlayerSessionService < Protocol::GameServerService::Service
    def initialize
      @sessions = Concurrent::Hash.new
      @logger = Rails.logger
    end

    # Gateway通过这个双向流连接到GameServer
    # Gatewayを通じてGameServerに双方向ストリームで接続
    # 一个流 = 一个玩家会话 / 1つのストリーム = 1つのプレイヤーセッション
    def player_session(gateway_messages)
      session_id = SecureRandom.uuid

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

      @logger.debug "Received message: protocol_id=#{protocol_id}, data_size=#{data.bytesize}"

      # 根据protocol_id处理不同的消息
      # TODO: 这里根据rotocol_types.rb来解析具体消息类型
      # 示例：echo back
      response = Protocol::G2GMessage.new(
        protocol_id: protocol_id,
        data: "Echo: #{data}".b
      )

      yielder << response
    rescue StandardError => e
      @logger.error "Error handling message: #{e.message}"
    end

    def cleanup_session(session_id)
      @sessions.delete(session_id)
      @logger.info "Session cleaned up: #{session_id}"
    end
  end
end

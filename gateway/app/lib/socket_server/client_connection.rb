require_relative '../protos/protocol_types'

module SocketServer
  class ClientConnection
    attr_reader :client_id, :address, :socket
    attr_accessor :user_id, :authenticated

    HEARTBEAT_TIMEOUT = 60

    AUTH_TIMEOUT = 2

    def initialize(client_id:, socket:, address:, server:, logger:)
      @client_id = client_id
      @socket = socket
      @address = address
      @server = server
      @logger = logger

      @protocol_handler = ProtocolHandler.new(logger: @logger)

      @user_id = nil
      @authenticated = false
      @closed = false

      @last_heartbeat = Time.now
      @heartbeat_timeout = HEARTBEAT_TIMEOUT

      @connected_at = Time.now
      @heartbeat_thread = nil
      @auth_thread = nil
    end

    def handle
      @logger.info "接続: #{@client_id}"

      # 最初のメッセージ (Connected)
      send_message(Protocol::Connected.new(client_id: @client_id))

      # authへタイムアウト監視を起動
      @auth_thread = Thread.new { auth_timeout_monitor }

      # メッセージ受信と処理
      loop do
        message = receive_message
        break if message.nil? # is close or error

        handle_message(message)
      end

      # 監視停止
      if @heartbeat_thread != nil
        @heartbeat_thread&.kill
        @logger.debug "client #{@client_id} @@heartbeat_thread killed"
      end
      if @auth_thread != nil
        @auth_thread&.kill
        @logger.debug "client #{@client_id} @auth_thread killed"
      end
    rescue => e
      @logger.error "client #{@client_id} error: #{e.message}"
      @logger.error e.backtrace.join("\n")
    ensure
      close
    end

    # Use ProtocolHandler to receive message
    # @return [Hash, nil] { protocol_id: Integer, message: Protocol::XXX }
    def receive_message
      result = @protocol_handler.decode(@socket)

      if result
        @logger.debug "Received from #{@client_id}: protocol_id=#{result[:protocol_id]}"
      end

      result
    rescue EOFError
      @logger.info "account #{@client_id} closed...(EOF)"
      nil
    rescue => e
      @logger.error "メッセージ受信エラー, account:  #{@client_id}: #{e.message}"
      nil
    end

    # 発信
    # @param message [Google::Protobuf::MessageExts] protobuf メッセージ
    # @return [Boolean]
    def send_message(message)
      return false if @closed

      protocol_id = ProtocolTypes.get_id(message)
      success = @protocol_handler.send_message(@socket, message)

      if success
        @logger.debug "Sent to #{@client_id}: protocol_id=#{protocol_id}, #{message.class.name}"
      else
        @logger.error "send message failed, account: #{@client_id}"
        close
      end

      success
    rescue => e
      @logger.error "送信エラー account: #{@client_id}: #{e.message}"
      close
      false
    end

    def close
      return if @closed

      @closed = true
      @logger.info "closed account: #{@client_id}, USERID: #{@user_id})"

      begin
        @socket.close unless @socket.closed?
      rescue => e
        @logger.error "closed socket error, account  #{@client_id}: #{e.message}"
      end

      # 認証されたと
      cleanup_user_mapping if @authenticated
    end

    def closed?
      @closed || @socket.closed?
    end

    private

    def handle_message(result)
      unless result.is_a?(Hash) && result[:protocol_id] && result[:message]
        @logger.warn "無効メッセージ形式、from #{@client_id}"
        send_message(Protocol::Error.new(reason: 'Invalid message format'))
        return
      end

      protocol_id = result[:protocol_id]
      message = result[:message]

      case protocol_id
      when ProtocolTypes::C2S_VERIFY_TOKEN
        handle_auth(message)
      when ProtocolTypes::C2S_HEARTBEAT
        handle_heartbeat(message)
      else
        @logger.warn "不明メッセージタイプ: protocol_id=#{protocol_id}, from: #{@client_id}"
        send_message(Protocol::Error.new(reason: "Unknown message type: #{protocol_id}"))
      end
    rescue => e
      @logger.error "handle_message error,from: #{@client_id}: #{e.message}"
      @logger.error e.backtrace.join("\n")
      send_message(Protocol::Error.new(reason: 'Internal server error'))
    end

    # 認証処理
    # @param message [Protocol::Auth]
    def handle_auth(message)
      if @authenticated
        send_message(Protocol::Error.new(reason: 'Already authenticated'))
        return
      end

      token = message.token
      unless token && !token.empty?
        @logger.warn "token欠如,from:　#{@client_id}"
        send_message(Protocol::AuthFailed.new(reason: 'Token required'))
        close
        return
      end

      # token検証  todo
      user = verify_token(token)

      if user
        @user_id = user.id
        @authenticated = true

        # 認証成功後、認証タイムアウト監視を停止、heartbeat監視開始
        @auth_thread&.kill
        @auth_thread = nil
        @logger.debug "client #{@client_id} @auth_thread killed"
        #　heartbeat監視開始
        @heartbeat_thread = Thread.new { heartbeat_monitor }

        @logger.info "account: #{@client_id} user_id #{@user_id}"

        # 認証成功後、@clientsに追加
        @server.add_authenticated_client(@client_id, self)

        # todo 必要性を検討
        store_user_mapping

        send_message(Protocol::AuthSuccess.new(user_id: @user_id))
      else
        @logger.warn "認証失敗,account: #{@client_id}"
        send_message(Protocol::AuthFailed.new(reason: 'Invalid token'))
        close
      end
    end

    # 心跳処理
    # @param message [Protocol::Heartbeat]
    def handle_heartbeat(message)
      @last_heartbeat = Time.now
    end

=begin
    # 处理聊天消息
    def handle_chat(message)
      unless @authenticated
        send_message({ type: 'error', reason: 'Authentication required' })
        return
      end

      text = message[:text]
      unless text && !text.empty?
        send_message({ type: 'error', reason: 'Message text required' })
        return
      end

      @logger.info "聊天消息，来自用户 #{@user_id}: #{text}"

      # 广播给所有客户端
      @server.broadcast({
                          type: 'chat',
                          user_id: @user_id,
                          text: text,
                          timestamp: Time.now.to_i
                        })
    end

    # 处理游戏操作消息
    def handle_game_action(message)
      unless @authenticated
        send_message({ type: 'error', reason: 'Authentication required' })
        return
      end

      action = message[:action]
      data = message[:data]

      unless action
        send_message({ type: 'error', reason: 'Action required' })
        return
      end

      @logger.info "游戏操作，来自用户 #{@user_id}: #{action}"

      # 推送到Redis队列以供后台处理
      begin
        Redis.current.lpush('game_actions', {
          user_id: @user_id,
          client_id: @client_id,
          action: action,
          data: data,
          timestamp: Time.now.to_i
        }.to_json)

        send_message({
                       type: 'action_received',
                       action: action,
                       timestamp: Time.now.to_i
                     })
      rescue => e
        @logger.error "推送游戏操作到Redis错误: #{e.message}"
        send_message({ type: 'error', reason: 'Failed to process action' })
      end
    end
=end

    def heartbeat_monitor
      loop do
        sleep 10 # todo config

        time_since_heartbeat = Time.now - @last_heartbeat
        if time_since_heartbeat > @heartbeat_timeout
          @logger.warn "account: #{@client_id} heartbeat timeout (#{time_since_heartbeat.to_i})"
          close
          break
        end
      end
    rescue => e
      @logger.error "heartbeat_monitor error, account: #{@client_id}: #{e.message}"
    end

    def auth_timeout_monitor
      sleep AUTH_TIMEOUT

      unless @authenticated
        @logger.warn "account: #{@client_id}　認証タイムアウト"
        close
      end
    rescue => e
      @logger.error "auth_timeout_monitor error, account: #{@client_id}: #{e.message}"
    end

    # token認証
    # @param token [String]
    # @return [User, nil] 無効とnil
    def verify_token(token)
      # TODO token認証実現

    rescue => e
      @logger.error "verify_token, account: #{e.message}"
      nil
    end

    # todo 必要性検討
    def store_user_mapping
      return unless @user_id

      begin
        # user_id -> client_id
        Redis.current.hset('user_to_client', @user_id, @client_id)
        # client_id -> user_id
        Redis.current.hset('client_to_user', @client_id, @user_id)
        # タイムアウト時間設定(例外を防ぐ)
        Redis.current.expire("user_to_client", 86400) # 24時間
        Redis.current.expire("client_to_user", 86400)
      rescue => e
        @logger.error "store_user_mapping error: #{e.message}"
      end
    end

    # todo 必要性検討
    def cleanup_user_mapping
      return unless @user_id

      begin
        Redis.current.hdel('user_to_client', @user_id)
        Redis.current.hdel('client_to_user', @client_id)
      rescue => e
        @logger.error "cleanup_user_mapping error: #{e.message}"
      end
    end
  end
end
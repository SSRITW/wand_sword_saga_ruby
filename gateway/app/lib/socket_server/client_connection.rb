require "json"

module SocketServer
  class ClientConnection
    attr_reader :client_id, :address, :socket
    attr_accessor :user_id, :authenticated

    HEARTBEAT_TIMEOUT = 60

    AUTH_TIMEOUT = 30

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
    end

    def handle
      @logger.info "接続: #{@client_id}"

      # 最初のメッセージ
      send_message({ type: 'connected', client_id: @client_id, timestamp: Time.now.to_i })

      # heartbeat,authへタイムアウト監視を起動
      heartbeat_thread = Thread.new { heartbeat_monitor }
      auth_thread = Thread.new { auth_timeout_monitor }

      # メッセージ受信と処理
      loop do
        message = receive_message
        break if message.nil? # is close or error

        handle_message(message)
      end

      # 監視停止
      heartbeat_thread&.kill
      auth_thread&.kill
    rescue => e
      @logger.error "client #{@client_id} error: #{e.message}"
      @logger.error e.backtrace.join("\n")
    ensure
      close
    end

    # Use ProtocolHandler to receive message
    def receive_message
      message = @protocol_handler.decode(@socket)

      if message
        @logger.debug "account: #{@client_id}: #{message[:type]}"
      end

      message
    rescue EOFError
      @logger.info "account #{@client_id} closed...(EOF)"
      nil
    rescue => e
      @logger.error "メッセージ受信エラー, account:  #{@client_id}: #{e.message}"
      nil
    end

    # 発信
    # @param message [Hash]　todo protobuf
    # @return [Boolean]
    def send_message(message)
      return false if @closed

      success = @protocol_handler.send_message(@socket, message)

      if success
        @logger.debug "to account: #{@client_id}: #{message[:type]}"
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

    def handle_message(message)
      unless message.is_a?(Hash) && message[:type]
        @logger.warn "無効メッセージ形式、from #{@client_id}"
        send_message({ type: 'error', reason: 'Invalid message format' })
        return
      end

      case message[:type]
      when 'auth'
        handle_auth(message)
      when 'heartbeat', 'ping'
        handle_heartbeat(message)
      when 'chat'
        # handle_chat(message)
      when 'game_action'
        #handle_game_action(message)
      else
        @logger.warn "不明メッセージタイプ: #{message[:type]}, from: #{@client_id}"
        send_message({ type: 'error', reason: "Unknown message type: #{message[:type]}" })
      end
    rescue => e
      @logger.error "handle_message error,from: #{@client_id}: #{e.message}"
      @logger.error e.backtrace.join("\n")
      send_message({ type: 'error', reason: 'Internal server error' })
    end

    # 認証処理
    def handle_auth(message)
      if @authenticated
        send_message({ type: 'error', reason: 'Already authenticated' })
        return
      end

      token = message[:token]
      unless token
        @logger.warn "token欠如,from:　#{@client_id}"
        send_message({ type: 'auth_failed', reason: 'Token required' })
        close
        return
      end

      # token検証
      user = verify_token(token)

      if user
        @user_id = user.id
        @authenticated = true
        @logger.info "account: #{@client_id} user_id #{@user_id}"

        # todo 必要性を検討
        store_user_mapping

        send_message({
          type: 'auth_success',
          user_id: @user_id,
          timestamp: Time.now.to_i
        })
      else
        @logger.warn "認証失敗,account: #{@client_id}"
        send_message({ type: 'auth_failed', reason: 'Invalid token' })
        close
      end
    end

    def handle_heartbeat(message)
      @last_heartbeat = Time.now
      # todo 必要性を検討
      send_message({
        type: 'pong',
        timestamp: Time.now.to_i
      })
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
          @logger.warn " account: #{@client_id} timeout (#{time_since_heartbeat.to_i}�)"
          send_message({ type: 'timeout', reason: 'Heartbeat timeout' })
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
        send_message({ type: 'timeout', reason: 'Authentication timeout' })
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
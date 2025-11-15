require_relative '../protos/protocol_types'
require_relative '../grpc_client/game_server_client'

module SocketServer
  class ClientConnection
    attr_reader :client_id, :address, :socket
    attr_accessor :user_id, :authenticated

    HEARTBEAT_TIMEOUT = 60

    AUTH_TIMEOUT = 5

    KEY_BASIS = 73

    def initialize(client_id:, socket:, address:, server:, logger:)
      @client_id = client_id
      @socket = socket
      @address = address
      @server = server
      @logger = logger
      # メッセージ暗号化キー
      @key = rand(2**23)

      @protocol_handler = ProtocolHandler.new(logger: @logger)

      @user_id = nil
      @authenticated = false
      @closed = false

      @last_heartbeat = Time.now
      @heartbeat_timeout = HEARTBEAT_TIMEOUT

      @connected_at = Time.now
      @heartbeat_thread = nil
      @auth_thread = nil

      # gRPC クライアント / gRPC 客户端
      @grpc_client = nil  # 添加这行
    end

    def handle
      @logger.info "接続: #{@client_id}"

      # 最初のメッセージ (S2C_Key)
      send_message(Protocol::S2C_Key.new(key: @key))

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
      result = @protocol_handler.decode(@socket,@key)

      if result
        @logger.debug "Received from #{@client_id}: protocol_id=#{result[:protocol_id]}"
      end
      #次のキーを設置
      next_key_set
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



    def closed?
      @closed || @socket.closed?
    end

    private

    def handle_message(result)
      unless result.is_a?(Hash) && result[:protocol_id] && result[:message]
        @logger.warn "無効メッセージ形式、from #{@client_id}"
        close
        return
      end

      protocol_id = result[:protocol_id]
      message = result[:message]

      case protocol_id
      when ProtocolTypes::C2S_LoginGameServer
        handle_login_game_server(message)
      when ProtocolTypes::C2S_HEARTBEAT
        handle_heartbeat(message)
      else
        # メッセージの転送
        @grpc_client.send_message(protocol_id,  message)
      end
    rescue => e
      @logger.error "handle_message error,from: #{@client_id}: #{e.message}"
      @logger.error e.backtrace.join("\n")
      close
    end

    # 認証処理
    # @param message [Protocol::Auth]
    def handle_login_game_server(message)
      if @authenticated
        # todo 重複のレクエスト？
        return
      end

      token = message.token
      unless token && !token.empty?
        @logger.warn "token欠如,from:　#{@client_id}"
        send_message(Protocol::S2C_LoginGameServer.new(code: Protocol::ErrorCode::AUTH_TOKEN_REQUIRED))
        close
        return
      end

      # token検証  todo
      user = verify_token(token)

      # todo
      if user
        @user_id = 123124
        @authenticated = true

        # 認証成功後、認証タイムアウト監視を停止、heartbeat監視開始
        @auth_thread&.kill
        @auth_thread = nil
        @logger.debug "client #{@client_id} @auth_thread killed"
        # heartbeat監視開始
        @heartbeat_thread = Thread.new { heartbeat_monitor }

        @logger.info "account: #{@client_id} user_id #{@user_id}"

        # 認証成功後、@clientsに追加
        @server.add_authenticated_client(@client_id, self)

        # ===== 追加：GameServerに接続 =====
        connect_to_game_server
      else
        @logger.warn "認証失敗,account: #{@client_id}"
        send_message(Protocol::S2C_VerifyToken.new(code: Protocol::ErrorCode::AUTH_FAILED))
        close
      end
    end


    # 心跳処理
    # @param message [Protocol::Heartbeat]
    def handle_heartbeat(message)
      @last_heartbeat = Time.now
      @logger.debug "client #{@client_id} handle_heartbeat..."
    end

    # 次のキーを計算し、正整数を確保
    def next_key_set
      next_key = @key*KEY_BASIS + 1
      @key = next_key>=0?next_key:-next_key
    end

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
      true
    rescue => e
      @logger.error "verify_token, account: #{e.message}"
      nil
    end

    # GameServerに接続
    # 连接到GameServer
    def connect_to_game_server

      server_address = GameServerCache.get_available_server_address(@user_id)

      if server_address == nil
        @logger.error "No available game server for user #{@user_id}"
        send_message(Protocol::Error.new(reason: 'No available game server'))
        close
        return
      end

      @grpc_client = GrpcClient::GameServerClient.new(
        client_id: @client_id,
        server_address: server_address,
        logger: @logger
      )

      # レスポンスコールバック設定
      # 设置响应回调
      success = @grpc_client.connect do |response|
        send_message(response)
      end

      if success
        @logger.info "Client #{@client_id} connected to GameServer"

        # todo
        # 最初のメッセージをGameServerに送信
        # 向GameServer发送第一条协议
        first_message = encode(Protocol::Account_Connect.new(account_id: @client_id,user_id: @user_id))
        @grpc_client.send_message(ProtocolTypes::Account_Connect,  first_message)
      else
        @logger.error "Failed to connect client #{@client_id} to GameServer"
      end
    rescue => e
      @logger.error "connect_to_game_server error: #{e.message}"
      @logger.error e.backtrace.join("\n")
    end

    # GameServerにメッセージを送信
    # 向GameServer发送消息
    def send_to_game_server(protocol_id, data)
      return false unless @grpc_client && @grpc_client.connected?
      @grpc_client.send_message(protocol_id, data)
    rescue => e
      @logger.error "send_to_game_server error: #{e.message}"
      false
    end


    def close
      return if @closed

      @closed = true
      @logger.info "closed account: #{@client_id}, USERID: #{@user_id})"

      # gRPC接続を切断
      # 断开gRPC连接
      @grpc_client&.disconnect

      begin
        @socket.close unless @socket.closed?
      rescue => e
        @logger.error "closed socket error, account  #{@client_id}: #{e.message}"
      end

    end

  end
end
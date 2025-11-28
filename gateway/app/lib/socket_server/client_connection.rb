require_relative '../protos/protocol_types'
require_relative '../grpc_client/game_server_client'
require "async"

module SocketServer
  class ClientConnection
    attr_reader :account_id, :client_id, :address, :socket
    attr_accessor :authenticated

    HEARTBEAT_TIMEOUT = 60

    # ハートビート間隔
    HEARTBEAT_CHECK_INTERVAL = 10

    # ハートビートが異常（加速）数の制限
    HEARTBEAT_CHEAT_COUNT_MAX = 10

    AUTH_TIMEOUT = 5

    KEY_BASIS = 73

    def initialize(socket:, address:, server:, logger:)
      @socket = socket
      @address = address
      @server = server
      @logger = logger
      # メッセージ暗号化キー
      @key = rand(2**23)

      @protocol_handler = ProtocolHandler.new(logger: @logger)
      # account_id
      @client_id = nil
      @user_id = nil
      @connect_show_server_id = nil
      @authenticated = false
      @closed = false

      @last_heartbeat = Time.now.to_i

      @connected_at = Time.now
      @heartbeat_thread = nil
      @auth_thread = nil

      # gRPC クライアント / gRPC 客户端
      @grpc_client = nil  # 添加这行
    end

    def handle
      @logger.info "接続: #{@address}"
      # 最初のメッセージ (S2C_Key)
      send_message(Protocol::S2C_Key.new(key: @key))

      # authへタイムアウト監視を起動
      @auth_thread = Async { auth_timeout_monitor }

      # メッセージ受信と処理
      loop do
        message = receive_message
        break if message.nil? # is close or error

        handle_message(message)
      end

      # 監視停止
      if @heartbeat_thread != nil
        @heartbeat_thread.stop
        @logger.debug "client #{@client_id} @heartbeat_thread stopped"
      end
      if @auth_thread != nil
        @auth_thread.stop
        @logger.debug "client #{@client_id} @auth_thread stopped"
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

      if result && result[:protocol_id] != ProtocolTypes::C2S_HEARTBEAT
        @logger.debug "Received from #{@client_id}:。。。protocol_id=#{result[:protocol_id]}"
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
      when ProtocolTypes::C2S_LOGIN_GAME_SERVER
        handle_login_game_server(message)
      when ProtocolTypes::C2S_HEARTBEAT
        handle_heartbeat(message)
      else
        if @authenticated
          # メッセージの転送
          @grpc_client.send_message(protocol_id,  message.class.encode(message))
        else
          @logger.error "[#{@client_id},#{@address} ]handle_message not authenticated try to send: #{protocol_id}"
        end
      end
    rescue => e
      @logger.error "handle_message error,from: #{@client_id}, #{@address} : #{e.message}"
      @logger.error e.backtrace.join("\n")
      close
    end

    # 認証処理
    # @param message [Protocol::Auth]
    def handle_login_game_server(message)
      if @authenticated
        @logger.warn "重複のloginレクエスト,token: #{message.token}, @address:#{@address} "
        return
      end

      token = message.token
      show_server_id = message.show_server_id
      if token.empty? || show_server_id.nil?
        @logger.warn "C2S_LoginGameServer token or show_server_id is nil,from:　#{@address}"
        close
        return
      end

      # token検証
      account_data = $redis.get(Constants::RedisConstants::LOGIN_TOKEN_PREFIX + token)
      if account_data.empty?
        @logger.warn "認証失敗,token: #{token}"
        send_message(Protocol::S2C_LoginGameServer.new(code: Protocol::ErrorCode::AUTH_FAILED))
        close
        return
      end

      account_info = JSON.parse(account_data)
      account_id = account_info["account_id"]

      connect_info = GameServerCache.server_address_get(show_server_id)
      if connect_info["address"] == nil || connect_info["address"] == ""
        send_message(Protocol::S2C_LoginGameServer.new(code: Protocol::ErrorCode::GAME_SERVER_UNAVAILABLE))
        return
      end

      if connect_info["allow_connect"] == false
        send_message(Protocol::S2C_LoginGameServer.new(code: Protocol::ErrorCode::GAME_SERVER_MAINTENANCE))
        return
      end
      # 検証完了とtokenを消耗
      $redis.del(Constants::RedisConstants::LOGIN_TOKEN_PREFIX + token)

      @connect_show_server_id = show_server_id
      @client_id = account_id
      @authenticated = true

      # 認証成功後、認証タイムアウト監視を停止、heartbeat監視開始
      @auth_thread&.stop
      @auth_thread = nil
      @logger.debug "client #{@client_id} @auth_thread stopped"
      # heartbeat監視開始
      @last_heartbeat = Time.now.to_i
      @heartbeat_illegal_counter = 0
      @heartbeat_thread = Async { heartbeat_monitor }

      @logger.info "account: #{@client_id} connect..."

      # 認証成功後、@clientsに追加
      @server.add_authenticated_client(@client_id, self)

      # ===== 追加：GameServerに接続 =====
      connect_to_game_server(connect_info["address"])
    end


    # 心跳処理
    # @param message [Protocol::Heartbeat]
    def handle_heartbeat(message)
      now_time = Time.now.to_i
      interval = now_time - @last_heartbeat
      if interval < HEARTBEAT_CHECK_INTERVAL
        @heartbeat_illegal_counter = @heartbeat_illegal_counter+1
        if @heartbeat_illegal_counter >= HEARTBEAT_CHEAT_COUNT_MAX
          @logger.warn "client #{@client_id}, heartbeat チート行為で、オフラインする..."
          close
          return
        end
      end
      @heartbeat_illegal_counter = 0
      @last_heartbeat = now_time
    end

    # 次のキーを計算し、正整数を確保
    def next_key_set
      next_key = @key*KEY_BASIS + 1
      @key = next_key>=0?next_key:-next_key
    end

    def heartbeat_monitor
      loop do
        sleep HEARTBEAT_CHECK_INTERVAL
        time_since_heartbeat = Time.now.to_i - @last_heartbeat
        if time_since_heartbeat > HEARTBEAT_TIMEOUT
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

    # GameServerに接続
    # 连接到GameServer
    def connect_to_game_server(server_address)

      if server_address == ""
        @logger.error "No available game server for account: #{@client_id}, show_server_id: #{@connect_show_server_id}"
        close
        return
      end

      @grpc_client = GrpcClient::GameServerClient.new(
        client_id: @client_id,
        server_address: server_address,
        logger: @logger
      )
      # todo grpc close
      # レスポンスコールバック設定
      # 设置响应回调
      success = @grpc_client.connect do |g2g_message|
        # ゼロコピー転送：GameServerからのbytesを直接転送
        # 零拷贝转发：直接转发 GameServer 的 bytes
        protocol_id = g2g_message.protocol_id
        data = g2g_message.data  # 保持 bytes，不解码

        # 直接发送原始数据，避免 decode + encode 的开销
        @protocol_handler.send_raw_message(@socket, protocol_id, data)
      end

      if success
        @logger.info "Client #{@client_id} connected to GameServer"
        # 最初のメッセージをGameServerに送信
        # 向GameServer发送第一条协议
        login_msg = Protocol::C2S_LoginGameServer.new(token: @client_id.to_s, show_server_id: @connect_show_server_id)
        first_message = Protocol::C2S_LoginGameServer.encode(login_msg)
        @grpc_client.send_message(ProtocolTypes::C2S_LOGIN_GAME_SERVER, first_message)
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
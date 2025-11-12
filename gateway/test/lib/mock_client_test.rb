require 'test_helper'
require 'socket'
require_relative '../../app/lib/protos/protocol_types'
require_relative '../../app/lib/utils/hmac_helper'

module SocketServer
  # モッククライアント：サーバーに接続してメッセージ送受信をシミュレート
  class MockClient
    KEY_BASIS = 73

    attr_reader :socket, :secret_key, :logger

    def initialize(host: '127.0.0.1', port:, logger: Logger.new(STDOUT))
      @host = host
      @port = port
      @secret_key = nil
      @logger = logger
      @socket = nil
      @connected = false
    end

    # サーバーに接続
    def connect
      @socket = TCPSocket.new(@host, @port)
      @connected = true
      @logger.info "サーバーに接続: #{@host}:#{@port}"
      true
    rescue => e
      @logger.error "接続エラー: #{e.message}"
      false
    end

    # 接続状態を確認
    def connected?
      @connected && @socket && !@socket.closed?
    end

    # サーバーからメッセージを受信してデコード
    def receive_message
      return nil unless connected?
      # 1. 長さを読み取る（4バイト）
      length_data = @socket.read(4)
      return nil if length_data.nil? || length_data.bytesize != 4

      message_length = length_data.unpack1('N')
      @logger.debug "受信メッセージ長: #{message_length}"

      # 2. プロトコルIDを読み取る（2バイト）
      protocol_id_data = @socket.read(2)
      return nil if protocol_id_data.nil? || protocol_id_data.bytesize != 2

      protocol_id = protocol_id_data.unpack1('n')
      @logger.debug "受信プロトコルID: #{protocol_id}"

      # 3. メッセージ本体を読み取る
      message_data = @socket.read(message_length)
      return nil if message_data.nil? || message_data.bytesize != message_length

      # 4. Protobufデコード
      message_class = ProtocolTypes.get_class(protocol_id)
      message = message_class.decode(message_data)

      @logger.info "メッセージ受信成功 : #{message.class.name}, data: #{message.to_s}"

      if protocol_id == ProtocolTypes::S2C_KEY
        @secret_key = message.key
        @logger.info "init key = #{@secret_key}"
      end

      {
        protocol_id: protocol_id,
        message: message
      }
    rescue EOFError
      @logger.warn "サーバー接続が閉じられました"
      nil
    rescue => e
      @logger.error "メッセージ受信エラー: #{e.message}"
      @logger.error e.backtrace.join("\n")
      nil
    end

    # メッセージをエンコードしてサーバーに送信
    def send_message(message)
      return false if !connected? || @secret_key.nil?

      # 1. プロトコルIDを取得
      protocol_id = ProtocolTypes.get_id(message)
      return false unless protocol_id

      # 2. Protobufエンコード
      message_bytes = message.class.encode(message)

      # 3. プロトコルIDデータ
      protocol_id_data = [protocol_id].pack('n')

      # 4. HMAC署名を生成
      payload = protocol_id_data + message_bytes
      hmac = Utils::HMACHelper.generate(payload, @secret_key.to_s, length: 8)

      # 5. パケット構築: [長さ][プロトコルID][HMAC][メッセージ本体]
      packet = [message_bytes.bytesize].pack('N') +
               protocol_id_data +
               hmac +
               message_bytes

      # 6. 送信
      @socket.write(packet)
      @socket.flush

      next_key = @secret_key * KEY_BASIS + 1
      @secret_key = next_key>=0?next_key:-next_key

      @logger.info "メッセージ送信成功: #{message.class.name}, プロトコルID: #{protocol_id}, next_key: #{next_key}"
      true
    rescue => e
      @logger.error "メッセージ送信エラー: #{e.message}"
      false
    end

    # 接続を閉じる
    def close
      if @socket && !@socket.closed?
        @socket.close
        @logger.info "接続を閉じました"
      end
      @connected = false
    end

    # サーバーからのメッセージを待機（ブロッキング、タイムアウト付き）
    def wait_for_message(timeout: 5)
      return nil unless connected?

      ready = IO.select([@socket], nil, nil, timeout)
      return nil unless ready

      receive_message
    end
  end

  # モッククライアントのテスト
  class MockClientTest < ActiveSupport::TestCase
    def setup
      @logger = Logger.new(STDOUT)
      @logger.level = Logger::DEBUG
=begin
      # テストサーバー起動
      @server_socket = TCPServer.new('127.0.0.1', 0)
      @server_port = @server_socket.addr[1]
      @logger.info "=== テストサーバー起動: ポート #{@server_port} ==="
=end

      @server_thread = nil
      @client = nil
    end

    def teardown
      @client&.close
      @server_thread&.kill
      @server_socket&.close
      @logger.info "=== テストサーバー停止 ==="
    end

    # ===== 基本接続テスト =====

    test "モッククライアント: サーバーに接続できる" do

      @client = MockClient.new(port: 9000, logger: @logger)
      result = @client.connect

      assert result, "接続成功"
      assert @client.connected?, "接続状態がtrue"

      # 0. サーバーからKEYメッセージを受信（重要！）
      @logger.info "サーバーからKEYメッセージを待機中..."
      key_msg = @client.receive_message
      refute_nil key_msg, "KEYメッセージを受信"
      refute_nil @client.secret_key, "secret_keyが初期化された"
      @logger.info "secret_key初期化完了: #{@client.secret_key}"

      # 1. Authメッセージ送信
      @logger.info "Authメッセージ送信中..."
      result1 = @client.send_message(Protocol::C2S_VerifyToken.new(token: "token1"))
      assert result1, "Authメッセージ送信成功"
      S2C_VerifyToken = @client.receive_message
      @logger.info "S2C_VerifyToken: #{S2C_VerifyToken[:message].code}"

      # 2. Heartbeatメッセージ送信
      (1...10).each do
        sleep(10)
        @logger.info "Heartbeatメッセージ送信中..."
        result2 = @client.send_message(Protocol::C2S_Heartbeat.new)
      end

      @client.close?
    end
  end
end

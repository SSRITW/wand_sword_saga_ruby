# GameServer gRPC クライアント
# GameServer gRPC 客户端
require 'grpc'
require_relative '../protos/msg_services_pb'

module GrpcClient
  class GameServerClient
    attr_reader :client_id, :logger

    # 初期化
    # 初始化
    # @param client_id [String] クライアントID / 客户端ID
    # @param server_address [String] GameServerアドレス / GameServer地址
    # @param logger [Logger] ロガー / 日志记录器
    def initialize(client_id:, server_address:, logger:)
      @client_id = client_id
      @server_address = server_address
      @logger = logger

      @stub = nil
      @stream_call = nil
      @request_queue = Queue.new
      @response_callback = nil
      @running = false
      @mutex = Mutex.new
    end

    # GameServerに接続して双方向ストリームを開始
    # 连接到GameServer并开始双向流
    # @param response_callback [Proc] レスポンスコールバック / 响应回调
    def connect(&response_callback)
      @mutex.synchronize do
        return false if @running

        @logger.info "Connecting to GameServer: #{@server_address} for client: #{@client_id}"

        begin
          # gRPC Stubを作成
          # 创建 gRPC Stub
          @stub = Protocol::GameServerService::Stub.new(
            @server_address,
            :this_channel_is_insecure
          )

          @response_callback = response_callback
          @running = true

          # リクエスト送信スレッド開始
          # 启动请求发送线程（同时处理响应接收）
          @request_thread = Thread.new { send_requests }

          @logger.info "gRPC stream established for client: #{@client_id}"
          true
        rescue => e
          @logger.error "Failed to connect to GameServer: #{e.message}"
          @logger.error e.backtrace.join("\n")
          cleanup
          false
        end
      end
    end

    # メッセージをGameServerに送信
    # 向GameServer发送消息
    # @param protocol_id [Integer] プロトコルID / 协议ID
    # @param data [String] シリアライズ済みデータ / 序列化后的数据
    def send_message(protocol_id, data)
      return false unless @running

      message = Protocol::G2G_Message.new(
        protocol_id: protocol_id,
        data: data
      )
      @request_queue << message
      @logger.debug "Queued message to GameServer: protocol_id=#{protocol_id}, client=#{@client_id}"
      true
    rescue => e
      @logger.error "Failed to queue message: #{e.message}"
      false
    end

    # 切断
    # 断开连接
    def disconnect
      @mutex.synchronize do
        return unless @running

        @logger.info "Disconnecting from GameServer for client: #{@client_id}"
        @running = false

        # キューに終了シグナルを送信
        # 向队列发送终止信号
        @request_queue << :stop

        # スレッドを終了
        # 终止线程
        # 避免线程 join 自己
        current = Thread.current
        @request_thread&.join(5) unless @request_thread == current

        cleanup
      end
    end

    # 接続状態チェック
    # 检查连接状态
    def connected?
      @running
    end

    private

    # リクエスト送信スレッド
    # 请求发送线程
    def send_requests
      # リクエストEnumeratorを作成
      # 创建请求Enumerator
      requests = Enumerator.new do |yielder|
        loop do
          message = @request_queue.pop
          break if message == :stop

          yielder << message
        end
      end

      # 双方向ストリーム呼び出し
      # 双向流调用
      @stream_call = @stub.player_session(requests)

      @logger.debug "Request sender started for client: #{@client_id}"
      
      # 重要：必须在这里迭代响应流
      # 重要：必须在这里迭代响应流
      @stream_call.each do |response|
        @logger.debug "Received from GameServer: protocol_id=#{response.protocol_id}, client=#{@client_id}"

        # コールバック呼び出し
        # 调用回调
        @response_callback&.call(response) if @running
      end

      @logger.debug "Stream ended for client: #{@client_id}"
    rescue => e
      @logger.error "Stream error for client #{@client_id}: #{e.message}"
      @logger.error e.backtrace.join("\n")
    ensure
      disconnect unless @running
    end

    # クリーンアップ
    # 清理资源
    def cleanup
      @stream_call = nil
      @stub = nil
      @request_queue.clear
      @logger.info "Cleaned up gRPC resources for client: #{@client_id}"
    end
  end
end

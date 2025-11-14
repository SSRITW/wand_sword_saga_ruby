# grpc service初期化
require 'grpc'

Rails.application.config.after_initialize do
  # コンソールとテスト環境以外で起動
  # 只在非控制台和非测试环境启动
  unless defined?(Rails::Console) || Rails.env.test?
    Thread.new do
      begin
        # 設定読み込み
        # 配置
        pool_size = ENV.fetch('GRPC_POOL_SIZE', 100).to_i
        max_waiting = ENV.fetch('GRPC_MAX_WAITING_REQUESTS', 20).to_i
        port = ENV.fetch('GRPC_PORT', '0.0.0.0:50051')

        # gRPC サーバー作成
        # 创建 gRPC 服务器
        server = GRPC::RpcServer.new(
          pool_size: pool_size,
          max_waiting_requests: max_waiting
        )

        # サービス登録
        # 注册服务
        require_relative '../../app/lib/grpc/player_session_service'
        server.add_http2_port(port, :this_port_is_insecure)

        # 全てのハンドラーを自動登録
        # 自动注册并构建所有handlers
        handlers = Handlers::BaseHandler.build_handlers(Rails.logger)
        server.handle(GrpcService::PlayerSessionService.new(handlers: handlers))


        Rails.logger.info "gRPC Server starting on #{port} (pool: #{pool_size}, queue: #{max_waiting})"

        # サーバー起動（ブロッキング）
        # 启动服务器（阻塞）
        server.run_till_terminated_or_interrupted([1, 'int', 'SIGTERM'])
      rescue => e
        Rails.logger.error "gRPC service error: #{e.message}"
        Rails.logger.error e.backtrace.join("\n")
      end
    end

    Rails.logger.info "gRPC service thread started in background"
  end
end
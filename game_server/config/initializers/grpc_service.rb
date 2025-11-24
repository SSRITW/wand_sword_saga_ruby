# grpc service初期化
require 'grpc'

# グローバル変数でサーバーを保持（優雅なシャットダウン用）
# 全局变量保存服务器引用（用于优雅关闭）
$grpc_server = nil

Rails.application.config.after_initialize do
  # コンソールとテスト環境、rakeタスク以外で起動
  # 只在非控制台、非测试环境、非rake任务时启动
  is_rake = defined?(Rake) && Rake.application.top_level_tasks.any?
  is_server = defined?(Rails::Server) || ENV['RAILS_SERVER']

  unless defined?(Rails::Console) || Rails.env.test? || is_rake || !is_server
    Thread.new do
      begin
        # 設定読み込み
        # 配置
        pool_size = ENV.fetch('GRPC_POOL_SIZE', 100).to_i
        max_waiting = ENV.fetch('GRPC_MAX_WAITING_REQUESTS', 20).to_i
        port = ENV.fetch('GRPC_PORT', '127.0.0.1:50051')

        # gRPC サーバー作成
        # 创建 gRPC 服务器
        $grpc_server = GRPC::RpcServer.new(
          pool_size: pool_size,
          max_waiting_requests: max_waiting
        )

        # サービス登録
        # 注册服务
        require_relative '../../app/lib/grpc/player_session_service'
        $grpc_server.add_http2_port(port, :this_port_is_insecure)

        # 全てのハンドラーファイルを読み込み
        # 加载所有 handler 文件
        Dir[Rails.root.join('app/grpc/handlers/**/*.rb')].each { |f| require f }

        # 全てのハンドラーを自動登録
        # 自动注册并构建所有handlers
        handlers = Handlers::BaseHandler.build_handlers(Rails.logger)
        $grpc_server.handle(GrpcService::PlayerSessionService.new(handlers: handlers))


        Rails.logger.info "gRPC Server starting on #{port} (pool: #{pool_size}, queue: #{max_waiting})"

        # サーバー起動（ブロッキング）
        # 启动服务器（阻塞）
        # Windows 兼容：使用 run 代替 run_till_terminated_or_interrupted
        if Gem.win_platform?
          $grpc_server.run
        else
          $grpc_server.run_till_terminated_or_interrupted(['INT', 'TERM'])
        end
      rescue => e
        Rails.logger.error "gRPC service error: #{e.message}"
        Rails.logger.error e.backtrace.join("\n")
      ensure
        $grpc_server = nil
      end
    end

    Rails.logger.info "gRPC service thread started in background"

    # シャットダウン時にgRPCサーバーを優雅に停止
    # 关闭时优雅停止 gRPC 服务器
    at_exit do
      if $grpc_server
        Rails.logger.info "Shutting down gRPC server..."
        begin
          $grpc_server.stop
        rescue => e
          # 静默处理关闭时的错误，避免输出大量日志
        end
        $grpc_server = nil
      end
    end
  end
end
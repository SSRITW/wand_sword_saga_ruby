# grpc service初期化
Rails.application.config.after_initialize do
  # 只在非控制台和非测试环境启动
  unless defined?(Rails::Console) || Rails.env.test?
    Thread.new do

      begin
        require_relative '../../app/lib/grpc_service/server'
        GrpcService::Server.start
      rescue => e
        Rails.logger.error "gRPC service error: #{e.message}"
        Rails.logger.error e.backtrace.join("\n")
      end
    end

    Rails.logger.info "gRPC service thread started in background"
  end
end
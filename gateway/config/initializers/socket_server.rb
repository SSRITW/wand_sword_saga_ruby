# socket server 初期化
Rails.application.config.after_initialize do
  Rails.logger.info "Socket Server initializing..."

  next if Rails.env.test? || defined?(Rails::Console)

  Thread.new do
    begin
      host = ENV.fetch('SOCKET_SERVER_HOST', '0.0.0.0')
      port = ENV.fetch('SOCKET_SERVER_PORT', '9000').to_i

      Rails.logger.info "=========================================="
      Rails.logger.info "Starting Socket Server"
      Rails.logger.info "Host: #{host}"
      Rails.logger.info "Port: #{port}"
      Rails.logger.info "Environment: #{Rails.env}"
      Rails.logger.info "=========================================="

      server = SocketServer::Server.new(host: host, port: port)

      Rails.application.config.socket_server = server

      server.start
    rescue => e
      Rails.logger.error "Socket Server fatal error: #{e.message}"
      Rails.logger.error e.backtrace.join("\n")
    end
  end

  Rails.logger.info "Socket Server thread started"

  at_exit do
    if defined?(Rails.application.config.socket_server)
      Rails.logger.info "Shutting down Socket Server..."
      Rails.application.config.socket_server&.stop
    end
  end
end
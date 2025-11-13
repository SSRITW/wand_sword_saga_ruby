require 'grpc'
require_relative 'player_session_service'

module GrpcService
  class Server
    @server = nil

    class << self
      def start
        @server = GRPC::RpcServer.new(
          pool_size: ENV.fetch('GRPC_POOL_SIZE', 100).to_i,  # 最大并发流数
          max_waiting_requests: ENV.fetch('GRPC_MAX_WAITING_REQUESTS', 10).to_i
        )

        port = ENV.fetch('GRPC_PORT', '0.0.0.0:50051')
        @server.add_http2_port(port, :this_port_is_insecure)
        @server.handle(PlayerSessionService.new)

        Rails.logger.info "gRPC Server running on #{port}"
        @server.run_till_terminated_or_interrupted([1, 'int', 'SIGTERM'])
      end

      def stop
        @server&.stop
        Rails.logger.info "gRPC Server stopped"
      end
    end
  end
end

require "socket"
require "securerandom"
require "async"
require_relative "client_connection"

module SocketServer
  class Server
    attr_reader :host, :port, :clients, :running

    def initialize(host: "0.0.0.0", port: 9000, logger: Rails.logger)
      @host = host
      @port = port
      @clients = Concurrent::Hash.new
      @running = false
      @logger = logger
      @server_socket = nil
    end

    # socket serverを起動
    def start
      @running = true
      @logger.info "Starting TCP Socket Server on #{@host}:#{@port}"

      Async do |task|
        @server_socket = TCPServer.new(@host, @port)
        @logger.info "Socket Server is listening on #{@host}:#{@port}"

        # 接続を受け取り
        while @running
          begin
            # 新しい接続 (Async 2.x handles non-blocking accept automatically)
            client_socket = @server_socket.accept

            # 単独処理 (Spawn a new async task for each client)
            task.async do
              handle_client(client_socket)
            end
          rescue => e
            break unless @running
            @logger.error "Error accepting connection: #{e.message}"
            @logger.error e.backtrace.join("\n")
          end
        end
      rescue => e
        @logger.error "Server error: #{e.message}"
        @logger.error e.backtrace.join("\n")
      ensure
        @running = false
        @server_socket&.close
        @logger.info "Server main loop exited"
      end
    end

    def stop
      @logger.info "Stopping TCP Socket Server..."
      @running = false

      # 全部の接続を停止
      @clients.each do |id, client|
        begin
          client.close
        rescue => e
          @logger.error "Error closing client #{id}: #{e.message}"
        end
      end

      @clients.clear
      @logger.info "TCP Socket Server stopped. All clients disconnected."
    end

    # 全部の接続に送信
    # @param message [Hash]
    def broadcast(message)
      count = 0
      @clients.each do |id, client|
        begin
          client.send_message(message)
          count += 1
        rescue => e
          @logger.error "Error broadcasting to client #{id}: #{e.message}"
          remove_client(id)
        end
      end
      @logger.debug "Broadcasted message to #{count} clients"
      count
    end

    # 指定の接続に送信
    # @param account_id [未定]
    # @param message [Hash]
    # @return [Boolean]
    def send_to_client(account_id, message)
      client = @clients[account_id]
      if client
        begin
          client.send_message(message)
          true
        rescue => e
          @logger.error "Error sending to client #{account_id}: #{e.message}"
          remove_client(account_id)
          false
        end
      else
        @logger.warn "Client #{account_id} not found"
        false
      end
    end


    def get_client(account_id)
      @clients[account_id]
    end


    def client_exists?(account_id)
      @clients.key?(account_id)
    end


    # @return [Integer]
    def client_count
      @clients.size
    end

    # 接続しているaccount_id
    def account_ids
      @clients.keys
    end

    def running?
      @running
    end

    # 認証成功後、クライアントを@clientsに追加
    # @param account_id [String]
    # @param connection [ClientConnection]
    def add_authenticated_client(account_id, connection)
      @clients[account_id] = connection
      @logger.info "Client #{account_id} authenticated and added to clients list. Active clients: #{@clients.size}"
    end

    private

    # 新接続を処理
    # @param socket [TCPSocket]
    def handle_client(socket)
      address = socket.peeraddr
      @logger.info "[Fiber:#{Fiber.current.object_id}] New connection from #{address.inspect}"
      
      connection = SocketServer::ClientConnection.new(
        socket: socket,
        address: address,
        server: self,
        logger: @logger
      )

      # 認証成功後に@clientsに追加されるため、ここでは追加しない

      # Handle client (blocking in this thread)
      begin
        connection.handle
      rescue => e
        @logger.error "Error handling client #{account_id}: #{e.message}"
        @logger.error e.backtrace.join("\n")
      ensure
        remove_client(connection.client_id)
      end
    end

    # 接続を削除
    def remove_client(account_id)
      client = @clients.delete(account_id)
      if client
        begin
          client.close unless client.closed?
        rescue => e
          @logger.error "Error closing client #{account_id}: #{e.message}"
        end
        @logger.info "Client #{account_id} disconnected. Active clients: #{@clients.size}"

        on_client_disconnected(account_id)
      end
    end

    # 切断時のCallback
    # @param account_id
    def on_client_disconnected(account_id)
      # Subclass can override this to implement custom logic
      # e.g. notify other systems, cleanup Redis data, etc.
    end
  end
end
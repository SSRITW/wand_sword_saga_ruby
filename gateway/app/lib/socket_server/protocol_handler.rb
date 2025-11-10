require 'json'

module SocketServer
  class ProtocolHandler
    # 最大消息大小 (1MB)
    MAX_MESSAGE_SIZE = 1024 * 1024

    # 协议格式: [4字节长度(大端序)][消息体]
    # Length: 32-bit unsigned integer, network byte order (big-endian)
    # Body: JSON encoded message

    def initialize(logger: Rails.logger)
      @logger = logger
    end

    # 从socket读取并解码消息
    # @param socket [Async::IO::Socket] socket对象
    # @return [Hash, nil] 解码后的消息Hash，或nil（如果失败）
    def decode(socket)
      # 读取4字节的消息长度
      length_data = socket.read(4)
      return nil if length_data.nil? || length_data.empty?

      # 解析长度（大端序，网络字节序）
      message_length = length_data.unpack1('N')

      # 验证消息大小
      unless valid_message_length?(message_length)
        @logger.error "Invalid message length: #{message_length}"
        return nil
      end

      # 读取消息体
      message_data = socket.read(message_length)
      return nil if message_data.nil? || message_data.bytesize != message_length

      # 解析JSON
      parse_json(message_data)
    rescue EOFError
      @logger.debug "Socket EOF reached"
      nil
    rescue => e
      @logger.error "Error decoding message: #{e.message}"
      nil
    end

    # 编码消息为字节流
    # @param message [Hash] 要编码的消息
    # @return [String, nil] 编码后的字节流，或nil（如果失败）
    def encode(message)
      # 转换为JSON
      message_json = message.to_json
      message_length = message_json.bytesize

      # 验证消息大小
      unless valid_message_length?(message_length)
        @logger.error "Message too large to encode: #{message_length} bytes"
        return nil
      end

      # 打包: [4字节长度][消息体]
      [message_length].pack('N') + message_json
    rescue => e
      @logger.error "Error encoding message: #{e.message}"
      nil
    end

    # 发送消息到socket
    # @param socket [Async::IO::Socket] socket对象
    # @param message [Hash] 要发送的消息
    # @return [Boolean] 是否成功发送
    def send_message(socket, message)
      data = encode(message)
      return false if data.nil?

      socket.write(data)
      socket.flush
      true
    rescue => e
      @logger.error "Error sending message: #{e.message}"
      false
    end

    private

    # 验证消息长度是否有效
    # @param length [Integer] 消息长度
    # @return [Boolean]
    def valid_message_length?(length)
      length > 0 && length <= MAX_MESSAGE_SIZE
    end

    # 解析JSON数据
    # @param data [String] JSON字符串
    # @return [Hash, nil]
    def parse_json(data)
      JSON.parse(data, symbolize_names: true)
    rescue JSON::ParserError => e
      @logger.error "Invalid JSON format: #{e.message}"
      nil
    end
  end

  # 扩展: MessagePack协议处理器（示例）
  # 如果将来需要支持MessagePack，可以这样实现：
  #
  # class MessagePackProtocolHandler < ProtocolHandler
  #   def parse_json(data)
  #     MessagePack.unpack(data, symbolize_keys: true)
  #   end
  #
  #   def encode(message)
  #     message_data = MessagePack.pack(message)
  #     message_length = message_data.bytesize
  #     [message_length].pack('N') + message_data
  #   end
  # end
end

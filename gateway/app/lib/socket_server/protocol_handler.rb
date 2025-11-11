require_relative '../protos/protocol_types'

module SocketServer
  class ProtocolHandler
    # メッセージ上限
    MAX_MESSAGE_SIZE = 1024 * 1024

    # protocolフォーマット: [4バイト長（big-endian）][2バイトprotocolID（big-endian）][protobufメッセージ本体]
    def initialize(logger: Rails.logger)
      @logger = logger
    end

    # socketからメッセージを読み取ってデコードする
    # @param socket [TCPSocket]
    # @return [Hash, nil] デコードしたデータ { protocol_id: Integer, message: Object }
    def decode(socket)
      # 1. 4バイトまでを読み取る
      length_data = socket.read(4)
      return nil if length_data.nil? || length_data.empty?

      message_length = length_data.unpack1('N')

      # メッセージ長さの合理性を検証
      unless valid_message_length?(message_length)
        @logger.error "Invalid message length: #{message_length}"
        return nil
      end

      # 2. 2バイトのプロトコルIDを読み取る
      protocol_id_data = socket.read(2)
      return nil if protocol_id_data.nil?

      protocol_id = protocol_id_data.unpack1('n')  # 'n' = unsigned short, big-endian

      # プロトコルIDを検証
      unless ProtocolTypes.valid_id?(protocol_id)
        @logger.error "Unknown protocol ID: #{protocol_id}"
        return nil
      end

      # 3. protobufメッセージ本体を読み取る（長さ = メッセージの長さ）
      # 3. 读取 protobuf 消息体（长度 = 协议本体的长度）
      message_data = socket.read(message_length)
      return nil if message_data.nil? || message_data.bytesize != message_length

      # 4. プロトコルIDに基づいてprotobufをデコード
      message_class = ProtocolTypes.get_class(protocol_id)
      message = message_class.decode(message_data)

      {
        protocol_id: protocol_id,
        message: message
      }
    rescue EOFError
      @logger.debug "Socket EOF reached"
      nil
    rescue => e
      @logger.error "Error decoding message: #{e.message}"
      @logger.error e.backtrace.join("\n")
      nil
    end

    # メッセージをバイトストリームにエンコード
    # @param message [Google::Protobuf::MessageExts] protobufメッセージオブジェクト
    # @return [String, nil] エンコードされたバイトストリーム
    def encode(message)
      # 1. プロトコルIDを取得
      protocol_id = ProtocolTypes.get_id(message)
      unless protocol_id
        @logger.error "Unknown message type: #{message.class}"
        return nil
      end

      # 2. protobufメッセージをエンコード
      message_bytes = message.class.encode(message)

      # 3. 全体の長さを計算 = protobufメッセージ本体
      # 3. 计算总长度 = protobuf消息体
      total_length = message_bytes.bytesize

      # メッセージサイズを検証
      unless valid_message_length?(total_length)
        @logger.error "Message too large: #{total_length} bytes"
        return nil
      end

      # 4. パック: [4バイト長][2バイトプロトコルID][protobufメッセージ本体]
      [total_length].pack('N') + [protocol_id].pack('n') + message_bytes
    rescue => e
      @logger.error "Error encoding message: #{e.message}"
      @logger.error e.backtrace.join("\n")
      nil
    end

    # socketにメッセージを送信
    # @param socket [TCPSocket]
    # @param message [Google::Protobuf::MessageExts]
    # @return [Boolean]
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

    # メッセージ長が有効かどうかを検証
    # @param length [Integer]
    # @return [Boolean]
    def valid_message_length?(length)
      length > 0 && length <= MAX_MESSAGE_SIZE
    end
  end
end
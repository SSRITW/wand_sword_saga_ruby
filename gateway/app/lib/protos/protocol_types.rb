require_relative 'msg_pb'

module SocketServer
  module ProtocolTypes
    # ========== サーバー -> クライアント (S2C) ==========
    S2C_KEY                        =    1  # S2C_Key
    S2C_VERIFY_TOKEN               =    2  # S2C_VerifyToken

    # ========== クライアント -> サーバー (C2S) ==========
    C2S_VERIFY_TOKEN               = 1000  # C2S_VerifyToken
    C2S_HEARTBEAT                  = 1001  # C2S_Heartbeat

    # プロトコル ID -> クラスマッピング
    ID_TO_CLASS = {
      S2C_KEY                        => Protocol::S2C_Key,
      S2C_VERIFY_TOKEN               => Protocol::S2C_VerifyToken,
      C2S_VERIFY_TOKEN               => Protocol::C2S_VerifyToken,
      C2S_HEARTBEAT                  => Protocol::C2S_Heartbeat,
    }.freeze

    # クラス -> プロトコル ID マッピング
    CLASS_TO_ID = ID_TO_CLASS.invert.freeze

    # プロトコル ID から対応するクラスを取得
    # @param protocol_id [Integer]
    # @return [Class, nil]
    def self.get_class(protocol_id)
      ID_TO_CLASS[protocol_id]
    end

    # メッセージオブジェクトからプロトコル ID を取得
    # @param message [Google::Protobuf::MessageExts]
    # @return [Integer, nil]
    def self.get_id(message)
      CLASS_TO_ID[message.class]
    end

    # プロトコル ID が有効かチェック
    # @param protocol_id [Integer]
    # @return [Boolean]
    def self.valid_id?(protocol_id)
      ID_TO_CLASS.key?(protocol_id)
    end
  end
end

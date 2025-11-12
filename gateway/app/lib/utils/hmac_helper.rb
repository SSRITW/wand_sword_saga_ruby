require 'openssl'

module Utils
  module HMACHelper
    # デフォルトHMAC長（バイト）
    HMAC_LENGTH_32 = 32
    HMAC_LENGTH_16 = 16
    HMAC_LENGTH_8 = 8

    # HMAC署名を生成
    # @param data [String] 署名するデータ
    # @param secret [String] 共有秘密鍵
    # @param length [Integer] HMAC切り取り長（バイト）、nilの場合は完全な32バイト
    # @return [String] HMAC署名（バイナリ文字列）
    def self.generate(data, secret, length: HMAC_LENGTH_16)
      hmac = OpenSSL::HMAC.digest('SHA256', secret, data)
      length ? hmac[0...length] : hmac
    end

    # HMACの16進数表現を生成（ログ/デバッグ用）
    # @param data [String] 署名するデータ
    # @param secret [String] 共有秘密鍵
    # @param length [Integer] HMAC切り取り長
    # @return [String] 16進数文字列
    def self.generate_hex(data, secret, length: HMAC_LENGTH_16)
      generate(data, secret, length: length).unpack1('H*')
    end

    # HMAC署名を検証
    # @param data [String] 元のデータ
    # @param received_hmac [String] 受信したHMAC署名
    # @param secret [String] 共有秘密鍵
    # @return [Boolean] 検証が成功したかどうか
    def self.verify(data, received_hmac, secret)
      length = received_hmac.bytesize
      calculated_hmac = generate(data, secret, length: length)

      # タイミング攻撃を防ぐために安全な比較を使用
      secure_compare(calculated_hmac, received_hmac)
    end

    # 安全な文字列比較（タイミング攻撃を防ぐ）
    # @param a [String]
    # @param b [String]
    # @return [Boolean]
    def self.secure_compare(a, b)
      return false unless a.bytesize == b.bytesize

      result = 0
      a.bytes.zip(b.bytes) { |x, y| result |= x ^ y }
      result == 0
    end
  end
end

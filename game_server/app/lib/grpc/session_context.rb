# セッションコンテキスト
# 会话上下文
# ハンドラーに渡されるセッション情報とヘルパーメソッドを提供
# 提供传递给 handler 的会话信息和辅助方法
class SessionContext
  attr_reader :session_id, :logger

  # 初期化
  # 初始化
  # @param session_id [String] セッションID / 会话ID
  # @param yielder [Object] gRPC yielder / gRPC yielder
  # @param session_data [Hash] 現在のセッションデータ / 当前会话数据
  # @param logger [Logger] ロガー / 日志记录器
  def initialize(session_id, yielder, session_data, logger)
    @session_id = session_id
    @yielder = yielder
    @session_data = session_data  # 只存储当前 session 的数据引用
    @logger = logger
  end

  # メッセージ送信（クライアントへ）
  # 发送消息到客户端
  # @param protocol_id [Integer] プロトコルID / 协议ID
  # @param data [String] シリアライズ済みデータ / 序列化后的数据
  def send_message(protocol_id, data)
    @yielder << Protocol::G2GMessage.new(
      protocol_id: protocol_id,
      data: data
    )
  rescue StandardError => e
    @logger.error "Failed to send message: protocol_id=#{protocol_id}, error=#{e.message}"
    raise
  end

  # セッションデータ取得
  # 获取会话数据
  # @return [Hash] セッションデータ / 会话数据
  def session_data
    @session_data
  end

  # セッションデータ更新
  # 更新会话数据
  # @param key [Symbol] キー / 键
  # @param value [Object] 値 / 值
  def update_session(key, value)
    @session_data[key] = value
    @logger.debug "Session updated: #{@session_id}, #{key}=#{value}"
  end

  # 最終アクティブ時刻を更新
  # 更新最后活跃时间
  def touch
    update_session(:last_active_at, Time.now)
  end

  # ユーザーIDを取得
  # 获取用户ID
  # @return [Integer, nil]
  def user_id
    @session_data[:user_id]
  end

  # ユーザーIDを設定
  # 设置用户ID
  # @param uid [Integer]
  def user_id=(uid)
    update_session(:user_id, uid)
  end

  # アカウントIDを取得
  # 获取账号ID
  # @return [String, nil]
  def account_id
    @session_data[:account_id]
  end

  # アカウントIDを設定
  # 设置账号ID
  # @param aid [String]
  def account_id=(aid)
    update_session(:account_id, aid)
  end

  # セッションが認証済みかチェック
  # 检查会话是否已验证
  # @return [Boolean]
  def authenticated?
    !user_id.nil? && !account_id.nil?
  end
end

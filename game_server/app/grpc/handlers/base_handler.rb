# 基础 Handler 类（带自动注册机制）
# すべてのハンドラーの基底クラス（自動登録機能付き）
module Handlers
  class BaseHandler
    def initialize(logger)
      @logger = logger
    end

    # 子类必须实现这个方法，返回协议ID到方法的映射
    # サブクラスはこのメソッドを実装する必要があります
    # @return [Hash] { protocol_id => Method }
    def handlers
      raise NotImplementedError, "#{self.class} must implement 'handlers' method"
    end

    # ========== 类级别的自动注册机制 / クラスレベルの自動登録機能 ==========
    class << self
      # 存储所有已注册的 handler 类
      # 登録済みハンドラークラスを保存
      def registered_handlers
        @registered_handlers ||= []
      end

      # 当子类继承时自动注册
      # サブクラスが継承されたときに自動登録
      def inherited(subclass)
        super
        registered_handlers << subclass unless registered_handlers.include?(subclass)
        Rails.logger.info "Registered handler: #{subclass.name}" if defined?(Rails)
      end

      # 构建协议路由表（类方法）
      # プロトコルルーティングテーブルを構築（クラスメソッド）
      # 组合所有 handler 的协议映射
      def build_handlers(logger)
        if registered_handlers.empty?
          logger.warn "No handlers registered! Make sure handler files are loaded."
          return {}
        end

        handlers_map = registered_handlers.flat_map do |handler_class|
          handler = handler_class.new(logger)
          handler.handlers.to_a
        end.to_h

        logger.info "Loaded #{handlers_map.size} protocol handlers from #{registered_handlers.size} handler classes"
        handlers_map
      end
    end

    protected

    # 辅助方法：发送响应消息到客户端（使用 context）
    # 補助メソッド：クライアントにレスポンスメッセージを送信（context使用）
    # @param context [SessionContext] セッションコンテキスト / 会话上下文
    # @param protocol_id [Integer] プロトコルID / 协议ID
    # @param response_data [String] レスポンスデータ / 响应数据
    def send_response(context, protocol_id, response_data)
      context.send_message(protocol_id, response_data)
    end

    # 辅助方法：记录错误
    # 補助メソッド：エラーをログ記録
    def log_error(message, exception = nil)
      @logger.error message
      if exception
        @logger.error exception.message
        @logger.error exception.backtrace.join("\n")
      end
    end
  end
end
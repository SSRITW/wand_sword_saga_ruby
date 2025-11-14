# 账号相关协议处理器
# アカウント関連のプロトコルハンドラー
module Handlers
  class AccountHandler < BaseHandler
    def handlers
      {
        SocketServer::ProtocolTypes::Account_Connect => method(:handle_account_connect)
      }
    end

    private

    # 最初のプロトコル。contextの初期化、アカウントとキャラクタの情報を戻る
    # 连接上的第一条协议，对上下文初始化，返回账号角色信息
    # @param message [Protocol::Account_Connect] メッセージ / 消息
    def handle_account_connect(message, context)
      @logger.info "Verifying token: #{message.token} (session: #{context.session_id})"

      # TODO: 实际的验证逻辑
      # 1. 验证token是否有效
      # 2. 从数据库加载用户信息
      # 3. 初始化会话状态
      account_id = "acc_#{context.session_id[0..7]}"
      context.user_id = 1213423
      context.account_id = account_id
      context.touch  # 更新最后活跃时间


      # 示例响应
      response_data = Protocol::S2C_LoginGameServer.new(
        code: 1,
        account_id: "acc_#{session_id[0..7]}",
        user_id: rand(10000..99999)
      ).to_proto

      send_response(
        context,
        SocketServer::ProtocolTypes::S2C_LoginGameServer,
        response_data
      )
    end
  end
end
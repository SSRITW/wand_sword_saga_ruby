# 账号相关协议处理器
# アカウント関連のプロトコルハンドラー
require_relative '../../lib/protos/protocol_types'
require_relative '../services/player_service'
require_relative '../services/load_service'

module Handlers
  class AccountHandler < BaseHandler
    def handlers
      {
        SocketServer::ProtocolTypes::C2S_LOGIN_GAME_SERVER => method(:handle_account_connect)
      }
    end

    private

    # 最初のプロトコル。contextの初期化、アカウントとキャラクタの情報を戻る
    # 连接上的第一条协议，对上下文初始化，返回账号角色信息
    # @param message [Protocol::C2S_LoginGameServer] メッセージ / 消息
    def handle_account_connect(message, context)
      @logger.info "handle_account_connect: [#{message.token}, #{message.show_server_id}] (session: #{context.session_id})"
      account_id = message.token.to_i
      p = PlayerService.login_of_register(context, account_id, message.show_server_id)

      info = p.player.to_proto

      response_data = Protocol::S2C_LoginGameServer.new(
        code: Protocol::ErrorCode::SUCCESS,
        account_id: account_id,
        player_id: p.player_id,
        info: info,
        is_init: p.player.is_init,
      ).to_proto

      context.send_message(SocketServer::ProtocolTypes::S2C_LOGIN_GAME_SERVER, response_data)

      LoadService.after_login_load(p)
      LoadService.after_login_send(p)
    end
  end
end
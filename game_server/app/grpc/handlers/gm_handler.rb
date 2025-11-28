module Handlers
  class GmHandler < BaseHandler
    def handlers
      {
        SocketServer::ProtocolTypes::C2S_GM => method(:handle_gm_operation)
      }
    end

    private
    def handle_gm_operation(message, context)
      if ENV.fetch('GRPC_POOL_SIZE', 0).to_i != 1
        Rails.logger.error "不正GMリクエスト:player_id=#{context.player_id}, gm_type: #{message.type}"
        # todo close
        return
      end
      # プレイヤーデータを取得
      # 使用 PlayerSessionHelper 获取玩家数据
      player_result = PlayerSessionHelper.online_player_data_get(context.player_id)
      if player_result["code"] != Protocol::ErrorCode::SUCCESS
        context.send_message(SocketServer::ProtocolTypes::S2C_GM,
                             Protocol::S2C_GM.new(code: player_result["code"]))
        return
      end
      player_data = player_result["player_data"]

      code = Protocol::ErrorCode::GM_UNKNOWN_TYPE
      case message.type
      when Constants::GmOperation::ITEM
        item_list =  [Protocol::AwardItem.new(id: message.param1, count: message.param2)]
        result = PlayerItemService.add_item(player_data, item_list, Constants::GameOperation::GM, "")
        code = result["code"]
      end

      context.send_message(SocketServer::ProtocolTypes::S2C_GM,
                           Protocol::S2C_GM.new(code: code))
    end
  end
end
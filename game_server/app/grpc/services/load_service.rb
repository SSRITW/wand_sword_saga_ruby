class LoadService

  # プレイヤーデータを全部メモリに保存
  def self.after_login_load(player_data)
    player_data.items = PlayerItemService.load_items(player_data)
    player_data.loading = false
  end

  # プレイヤーに全部のデータを送信
  def self.after_login_send(player_data)
    PlayerItemService.send_item_full_list(player_data)
    # send ending
    player_data.context.send_message(
      SocketServer::ProtocolTypes::S2C_LOAD_END,
      Protocol::S2C_LoadEnd.new
    )
  end
end
class PlayerService
  def self.login_of_register(account_id:, show_server_id:)
    p = Player.find_or_create_by(
      account_id: account_id,
      show_server_id: show_server_id
    ) do |new_player|
      new_player.player_id = IdGenerator.next_player_id(show_server_id)
      new_player.real_server_id = ENV["GAME_SERVER_ID"].to_i
      new_player.level = 1
      new_player.vip_level = 0
    end

    # todo 重复链接判断
    if $player_datas[p.player_id] != nil
      return $player_datas[p.player_id]
    end

    p.online_at = Time.now
    p.update("online_at")

    player_data =PlayerData.new(
      player_id: p.player_id,
      player: p,
      loading: true,
    )
    $player_datas[p.player_id] = player_data
    player_data
  end

  def self.offline(player_id)
    # todo
  end
end
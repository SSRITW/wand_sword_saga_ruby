require_relative '../../lib/models/player_data'

class PlayerService
  def self.login_of_register(context, account_id, show_server_id)
    p = Player.find_or_create_by(
      account_id: account_id,
      show_server_id: show_server_id
    ) do |new_player|
      new_player.player_id = IdGenerator.next_player_id(show_server_id)
      new_player.real_server_id = ENV["GAME_SERVER_ID"].to_i
      new_player.level = 1
      new_player.vip_level = 0
    end

    context.player_id = p.player_id
    context.account_id = account_id
    context.touch  # 更新最后活跃时间

    # todo もう一度レビューする必要がある
    if $player_datas[p.player_id] != nil
      if $player_datas[p.player_id].context == context
        Rails.logger.error "重複のlogin_of_registerリクエスト？: player_id=#{player_id}"
      else
        Rails.logger.debug "再接続？: player_id=#{player_id}"
      end
      $player_datas[p.player_id].context = context
      return $player_datas[p.player_id]
    end

    p.update(online_at: Time.now)

    player_data =PlayerData.new(
      player_id: p.player_id,
      player: p,
      loading: true,
      context: context,
    )
    $player_datas[p.player_id] = player_data
    player_data
  end

  # todo 遅延削除プレイヤーのメモリデータ
  def self.offline(player_id)
    if player_id==nil || player_id==0
      return
    end

    player_data = $player_datas.delete(player_id)
    if player_data == nil
      return
    end
    player_data.with_lock do
      begin
        # 更新数据库的离线时间
        Player.where(player_id: player_id).update_all(
          offline_at: Time.now
        )
        Rails.logger.info "Player offline: player_id=#{player_id}, online_duration=#{player_data.online_duration}s"
      rescue StandardError => e
        Rails.logger.error "Failed to save player offline data: player_id=#{player_id}, error=#{e.message}"
      end
    end
  end
end
class PlayerLevelService
  def self.level_up_check_and_update(player_data, now_exp)
    now_level = player_data.player.level

    max_level = GAME_TABLES.level_map.size
    return now_exp if now_level >= max_level

    while now_level<max_level
      level_config = GAME_TABLES.level_map[now_level]
      if level_config == nil
        Rails.logger.error "level configが存在しない:player_id=#{player_data.player_id} level=#{now_level}"
        break
      end
      # プレイヤーの突破リクエストする必要がある
      break if level_config.need_break == 1
      # 経験値不足
      break if now_exp < level_config.exp
      now_exp -= level_config.exp
      now_level+=1
    end

    if player_data.player.level != now_level
      player_data.player.level = now_level
      player_data.player.update(level: now_level)
    end

    return now_exp
  end
end
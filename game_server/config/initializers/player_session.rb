$player_datas = Concurrent::Map.new

# プレイヤーセッション管理のヘルパーモジュール
# 玩家会话管理辅助模块
module PlayerSessionHelper
  module_function

  # オンラインプレイヤーデータを取得（contextチェック付き）
  # 获取在线玩家数据（检查 context）
  # @param player_id [Integer] プレイヤーID / 玩家ID
  # @return [Hash] { "code" => ErrorCode, "player_data" => PlayerData|nil }
  def online_player_data_get(player_id)
    player_data = $player_datas[player_id]
    if player_data == nil
      Rails.logger.error "プレイヤーはplayer_datasに存在しないが、send_item_full_listを実行？: player_id=#{player_id}"
      return {"code" => Protocol::ErrorCode::PLAYER_DATA_NOT_EXIST, "player_data" => nil}
    end

    if player_data.context == nil
      Rails.logger.error "プレイヤーのcontextが存在しない、メッセージ送信不可: player_id=#{player_id}"
      return {"code" => Protocol::ErrorCode::PLAYER_OFFLINE, "player_data" => nil}
    end

    {"code" => Protocol::ErrorCode::SUCCESS, "player_data" => player_data}
  end

  # メモリ中のプレイヤーデータを取得
  # 获取内存中的玩家数据
  # @param player_id [Integer] プレイヤーID / 玩家ID
  # @return [Hash] { "code" => ErrorCode, "player_data" => PlayerData|nil }
  def player_data_get(player_id)
    player_data = $player_datas[player_id]
    if player_data == nil
      Rails.logger.error "プレイヤーはplayer_datasに存在しないが、send_item_full_listを実行？: player_id=#{player_id}"
      return {"code" => Protocol::ErrorCode::PLAYER_DATA_NOT_EXIST, "player_data" => nil}
    end

    {"code" => Protocol::ErrorCode::SUCCESS, "player_data" => player_data}
  end
end
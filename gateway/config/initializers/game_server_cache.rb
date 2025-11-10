# frozen_string_literal: true
require 'concurrent'

module GameServerCache
  GAME_SERVER_CACHE_KEY = "game_servers"
  GAME_SERVER_STATUS_REDIS_KEY = "game:svr:status"

  # スレッドセーフのデータ型を使い
  @game_servers = Concurrent::Map.new

  # gameServerの基本情報(DB)と起動状態(redis)を初期化
  # 初始化游戏服的基本信息(DB)和实际运行状态(redis)
  def self.init
    game_servers = GameServer.all.to_a
    game_servers_status = $redis.hgetall(GAME_SERVER_STATUS_REDIS_KEY)

    svr_map = Hash.new
    game_servers.each do |svr|
      # 起動状態を取得
      status_info = game_servers_status[svr.real_server_id]
      if status_info!=nil
        svr.connection_online = status_info.connection_online
        svr.connect_ip = status_info.connect_ip
      end
      Rails.logger.debug "game servers info: "+svr.to_s
      svr_map[svr.show_server_id]=svr
    end
    # キャッシュに保存
    @game_servers = Concurrent::Map.new(game_servers)
    Rails.logger.info "game servers initialized...size:"+game_servers.size.to_s
  end

  def self.change(real_id,connection_online,connect_ip)
    @game_servers.each do |svr|
      if real_id ==svr.real_server_id
        svr.connect_ip = connect_ip
        svr.connection_online = connection_online
        svr.last_heartbeat_timestamp = Time.now.to_i
      end
    end
  end

  def self.heartbeat(real_id)
    @game_servers.each do |svr|
      if real_id ==svr.real_server_id
        svr.last_heartbeat_timestamp = Time.now.to_i
      end
    end
  end

end


# 初期化した後実行
Rails.application.config.after_initialize do
  GameServerCache.init

  Thread.new do
    # game serverの状態変化を購読
    $redis.subscribe(Constants::RedisConstants::GAME_SERVER_STATUS_SUBSCRIBE_KEY,
                     Constants::RedisConstants::GAME_SERVER_HEARTBEAT_SUBSCRIBE_KEY) do |on|
      on.message do |_channel, _message|
        case _channel
        when Constants::RedisConstants::GAME_SERVER_STATUS_SUBSCRIBE_KEY
          server_info = JSON.parse(_message)
          GameServerCache.change(server_info[:real_server_id],server_info[:connection_online],server_info[:connect_ip])
          Rails.logger.info "game server　状態： #{_message}"
        when Constants::RedisConstants::GAME_SERVER_HEARTBEAT_SUBSCRIBE_KEY
          GameServerCache.heartbeat(_message.to_i)
        end
      end
    end
  end
  Rails.logger.info "初期化した。"
end


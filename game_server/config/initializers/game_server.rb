

GAME_SERVER_STATUS_REDIS_KEY = "game:svr:status"
SERVER_ID = ENV["GAME_SERVER_ID"].to_i
def server_heartbeat
  Thread.new do
    loop do
      sleep Constants::RedisConstants::GAME_SERVER_HEARTBEAT_INTERVAL
      begin
        $redis.publish(Constants::RedisConstants::GAME_SERVER_HEARTBEAT_SUBSCRIBE_KEY, SERVER_ID)
      rescue => e
        Rails.logger.error("[Heartbeat] Error: #{e.message}")
      end
    end
  end
end

def server_status_change(status)
  info_json = {
    real_server_id: ENV["GAME_SERVER_ID"].to_i,
    connection_online: status,
    connect_ip: ActionCable.server.config.cable["url"]
  }.to_json

  Rails.logger.debug "server_status_change: #{info_json}"
  # まず最新状態をredisに記入
  $redis.hset(GAME_SERVER_STATUS_REDIS_KEY,SERVER_ID,info_json)
  # 発散
  $redis.publish(Constants::RedisConstants::GAME_SERVER_STATUS_SUBSCRIBE_KEY, info_json)
end

Rails.application.config.after_initialize do
  # 初期化した同期状態
  server_status_change(true)
  # ハートビートを起動
  server_heartbeat

  # サービスがオフする時にまた状態をredisに発信
  at_exit do
    server_status_change(false)
  end
end

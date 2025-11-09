redis_config = Rails.application.config_for(:redis)
$redis = Redis.new(redis_config)


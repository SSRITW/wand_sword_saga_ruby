class AccountService
  # 登录或注册 / ログインまたは登録
  def self.login_of_register(account_name:, platform_id:, platform_type:)
    account_name_prefix = Account.account_name_prefix(platform_id)
    full_account_name = account_name_prefix + account_name
    account = Account.find_or_create_by(
      account_name: full_account_name,
      platform_id: platform_id
    ) do |new_account|
      new_account.account_id = IdGenerator.generate_id
      new_account.platform_type = platform_type
    end

    if account.persisted?
      # 生成 token / トークンを生成
      token = SecureRandom.hex(32)
      player_info = self.player_info_get(account.account_id)
      cache_token(account.account_id,player_info, token)
      {code: 1, token: token, player_info: player_info}
    else
      {code: -1, errors: account.errors.full_messages}
    end
  end

  # 获取玩家信息 / プレイヤー情報を取得
  def self.player_info_get(account_id)
    AccountPlayerInfo.where(account_id: account_id).to_a
  end

  private

  # 将 token 缓存到 Redis / トークンをRedisにキャッシュ
  def self.cache_token(account_id,player_info, token)
    token_key = Constants::RedisConstants::LOGIN_TOKEN_PREFIX + token
    expire_time = ENV.fetch('LOGIN_TOKEN_VALID_TIME', 300).to_i
    # 存储 token -> account_id 的映射 / token -> account_id のマッピングを保存
    $redis.setex(token_key, expire_time, {account_id: account_id, player_info: player_info}.to_s)
  end
end
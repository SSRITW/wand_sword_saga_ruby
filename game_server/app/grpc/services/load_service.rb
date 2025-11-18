class LoadService
  def after_login_load(player_data)
    player_data.items = load_item(player_data.player_id)
    player_data.loading = false
  end

  def load_item(player_id)
    Concurrent::Map.new
  end
end
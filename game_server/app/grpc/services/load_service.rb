class LoadService
  def self.after_login_load(player_data)
    player_data.items = load_item(player_data.player_id)
    player_data.loading = false
  end

  def self.load_item(player_id)
    Concurrent::Map.new
  end
end
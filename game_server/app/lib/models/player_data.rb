PlayerData = Struct.new(
  :player_id,
  :player,
  :items,
  :bag,
  :equipment,
  :quests,
  :mutex,
  :online_at,
  :loading,
  keyword_init: true
) do
  def initialize(**args)
    super
    self.mutex ||= Mutex.new
    self.online_at ||= Time.now
  end

  def with_lock(&block)
    mutex.synchronize(&block)
  end

end

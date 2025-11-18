class RemoveOnlineTimeAndOfflineTimeFromPlayers < ActiveRecord::Migration[8.1]
  def change
    remove_column :players, :online_time, :datetime
    remove_column :players, :offline_time, :datetime
  end
end

class AddOnlineTimeAndOfflineTimeToPlayers < ActiveRecord::Migration[8.1]
  def change
    add_column :players, :online_time, :datetime
    add_column :players, :offline_time, :datetime
  end
end

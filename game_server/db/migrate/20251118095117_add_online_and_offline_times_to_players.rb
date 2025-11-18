class AddOnlineAndOfflineTimesToPlayers < ActiveRecord::Migration[8.1]
  def change
    add_column :players, :online_at, :datetime
    add_column :players, :offline_at, :datetime
  end
end

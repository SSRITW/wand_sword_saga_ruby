class AddVipLevelAndIsInitToPlayers < ActiveRecord::Migration[8.1]
  def change
    add_column :players, :vip_level, :integer
    add_column :players, :is_init, :integer,limit: 2, default: 0
  end
end

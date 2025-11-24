class AddIsNewToPlayerItems < ActiveRecord::Migration[8.1]
  def change
    add_column :player_items, :is_new, :integer, default: 1, comment: "新規フラグ"
  end
end
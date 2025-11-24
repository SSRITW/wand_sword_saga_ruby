class CreatePlayerItems < ActiveRecord::Migration[8.1]
  def change
    create_table :player_items,id: false do |t|
      t.bigint :player_id, null: false, comment: "プレイヤーid"
      t.bigint :guid, null: false, comment: "id"
      t.integer :item_id, null: false, comment: "config_id"
      t.integer :count, default: 0, comment: "数"
      t.integer :is_new, default: 1, comment: "新規フラグ"
      t.timestamps
    end

    execute "ALTER TABLE player_items ADD PRIMARY KEY (player_id,guid);"
  end
end

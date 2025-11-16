class AccountPlayerInfo < ActiveRecord::Migration[8.1]
  def up
    create_table :account_player_infos, id: false do |t|
      t.bigint :account_id, null: false
      t.integer :show_server_id, null: false
      t.integer :real_server_id, null: false
      t.bigint :player_id, null: false
      t.string :player_name, null: false, default: ""
      t.integer :player_level, null: false, default: 1
      t.timestamps
    end

    # 添加联合主键
    execute "ALTER TABLE account_player_infos ADD PRIMARY KEY (account_id, show_server_id);"
  end

  def down
    drop_table :account_player_infos
  end
end

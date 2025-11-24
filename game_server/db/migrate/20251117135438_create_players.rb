class CreatePlayers < ActiveRecord::Migration[8.1]
  def change
    create_table :players,id: false do |t|
      t.bigint :player_id
      t.bigint :account_id
      t.integer :real_server_id
      t.integer :show_server_id
      t.string :nickname
      t.integer :sex
      t.integer :level
      t.bigint :exp
      t.integer :icon

      t.timestamps
    end

    execute "ALTER TABLE players ADD PRIMARY KEY (player_id);"
  end
end

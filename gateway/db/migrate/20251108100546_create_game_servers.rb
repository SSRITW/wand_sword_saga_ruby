class CreateGameServers < ActiveRecord::Migration[8.1]
  def change
    create_table :game_servers, id: false  do |t|
      t.integer :show_server_id, null: false#主キー
      t.integer :real_server_id, null: false #サーバー合併用
      t.string :name, null: false
      t.string :flag, default: "[]" #プラットフォームや設備タイプによるマーク
      t.integer :rcmd_status, default: 0 #推薦状態　0未解放（見えない、入れない）　1推薦 2並 3不推薦（新プレイヤーが入れない）
      t.integer :svr_status, default: 0 #サーバー状態　0未解放（見えない、入れない）　1解放中　2メンテナンス
      t.integer :open_time, default: 0 #解放時間

      t.timestamps
    end
    execute "ALTER TABLE game_servers ADD PRIMARY KEY (show_server_id);"
  end
end
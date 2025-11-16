class Account < ActiveRecord::Migration[8.1]
  def up
    create_table :accounts, id: false  do |t|
      t.bigint :account_id, null: false # 主キー
      t.string :account_name, null: false # カウント名
      t.integer :platform_id, null: false # 0guest,1x,2facebook,3google など
      t.integer :platform_type, null: false  # 1ios  2 android
      t.timestamps
    end
    execute "ALTER TABLE accounts ADD PRIMARY KEY (account_id);"
  end

  def down
    drop_table :accounts
  end
end

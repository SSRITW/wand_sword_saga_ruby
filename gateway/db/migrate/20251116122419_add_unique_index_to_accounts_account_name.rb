class AddUniqueIndexToAccountsAccountName < ActiveRecord::Migration[8.1]
  def change
    add_index :accounts, :account_name, unique: true
  end
end

class DropTestModels < ActiveRecord::Migration[8.1]
  def change
    drop_table :test_models
  end
end

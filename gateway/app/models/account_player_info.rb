class AccountPlayerInfo < ApplicationRecord
  # 声明联合主键 / 複合主キーを宣言
  self.primary_key = [:account_id, :show_server_id]

  # 验证 / バリデーション
  validates :account_id, presence: true
  validates :show_server_id, presence: true
  validates :real_server_id, presence: true
  validates :player_name, presence: true
  validates :player_level, presence: true, numericality: { greater_than_or_equal_to: 1 }

end
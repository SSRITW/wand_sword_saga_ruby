class Account < ApplicationRecord
  self.primary_key = 'account_id'

  # 平台 ID 枚举常量 / プラットフォームID列挙定数
  module PlatformId
    GUEST = 0
    X = 1
    FACEBOOK = 2
    GOOGLE = 3
  end

  # 设备类型枚举常量 / デバイスタイプ列挙定数
  module PlatformType
    IOS = 1
    ANDROID = 2
  end

  # 验证 / バリデーション
  validates :account_name, presence: true, uniqueness: true
  validates :platform_id, presence: true, inclusion: { in: [PlatformId::GUEST, PlatformId::X, PlatformId::FACEBOOK, PlatformId::GOOGLE] }
  validates :platform_type, presence: true, inclusion: { in: [PlatformType::IOS, PlatformType::ANDROID] }

  # 获取平台前缀（类方法） / プラットフォームプレフィックスを取得（クラスメソッド）
  def self.account_name_prefix(platform_id)
    case platform_id
    when PlatformId::GUEST
      'guest_'
    when PlatformId::X
      'x_'
    when PlatformId::FACEBOOK
      'facebook_'
    when PlatformId::GOOGLE
      'google_'
    else
      ''
    end
  end
end
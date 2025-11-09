class GameServer < ApplicationRecord
  serialize :flag, coder: JSON

  attr_accessor :connection_status, :boolean
  attr_accessor :connect_ip, :string
  attr_accessor :last_heartbeat_timestamp, :integer # 秒

  def allow_entry?(is_new=true)
    if rcmd_status == 0 || svr_status == 0 || svr_status == 2
       false
    elsif is_new && rcmd_status == 3
       false
    else 
       true
    end
  end
end
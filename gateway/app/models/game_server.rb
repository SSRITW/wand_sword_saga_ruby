class GameServer < ApplicationRecord
  serialize :flag, coder: JSON

  def allow_entry?(isNew=true)
    if rcmd_status == 0 || svr_status == 0 || svr_status == 2
      return false
    elsif isNew && rcmd_status == 3
      return false
    else 
      return true
    end
  end
  
end
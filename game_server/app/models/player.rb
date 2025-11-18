class Player < ApplicationRecord

  def to_proto
    Protocol::PlayerInfo.new(
      player_id: player_id,
      show_server_id: show_server_id,
      real_server_id: real_server_id,
      nickname: nickname || "",
      level: level || 1,
      vip_level: vip_level || 0,
      icon: icon || 0,
      sex: sex || 0
    )
  end
end

require "test_helper"

class GameServerTest < ActiveSupport::TestCase
  test "find" do
    find_all = GameServer.all
    find_all.each do |svr|
      puts "show_id: #{svr.show_server_id}, real_id: #{svr.real_server_id}, name: #{svr.name}, flag[0]: #{svr.flag.size > 0 ? svr.flag[0]:'null'}"
    end
    assert_equal 3, find_all.size
  end

  test "allow_entry" do
    assert GameServer.find(1).allow_entry?(true), "ノーマルな状態で入れない？"
    not_rcmd_svr = GameServer.find(2)
    assert_not not_rcmd_svr.allow_entry?(true), "推薦でない状態で新人が入れないべき:"+not_rcmd_svr.allow_entry?(true).to_s
    assert not_rcmd_svr.allow_entry?(false), "推薦でない状態でキャラクターを持っているプレイヤーが入れるべき:"
    fixing_svr = GameServer.find(3)
    assert_not fixing_svr.allow_entry?(false) || fixing_svr.allow_entry?(true), "メンテナンスの状態で誰でも入れないべき,notNew:"+
      fixing_svr.allow_entry?(false).to_s + ", isNew:" + fixing_svr.allow_entry?(true).to_s
  end
end

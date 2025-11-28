class PlayerItem < ApplicationRecord

  def to_proto
    Protocol::Item.new(
      guid: guid,
      item_id: item_id,
      item_num: count,
      is_new: is_new || 1,
    )
  end

  # 同じidのアイテムを合併する
  # 合并相同 id 的道具数量
  # @param item_list [Array<Cfg::EntityItem>] アイテムリスト / 道具列表
  # @return [Array<Cfg::EntityItem>] 合併後のアイテムリスト / 合并后的道具列表
  def self.merge_item(item_list)
    return [] if item_list.empty?

    item_list
      .group_by(&:id)
      .map { |id, items|
        Cfg::EntityItem.new(
          id: id,
          count: items.sum(&:count)
        )
      }
  end

end
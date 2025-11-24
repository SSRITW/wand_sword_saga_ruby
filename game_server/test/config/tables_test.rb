require 'test_helper'
require_relative '../../config/pb_datas/cfg/schema_tables'

class TablesTest < ActiveSupport::TestCase
  test "should load game data correctly" do
    # Assuming data is in config/pb_datas/data
    tables = Tables.new(Rails.root.join('config', 'pb_datas', 'data'))

    assert_not_nil tables.items, "Item config should be loaded"
    assert_not_nil tables.shops, "Shop config should be loaded"
    
    assert_kind_of Cfg::Item, tables.items
    assert_kind_of Cfg::Shop, tables.shops
    
    # 遍历 (Iterate) Items
    puts "--- Iterating Items ---"
    tables.items.data_list.each do |item|
      puts "Item ID: #{item.id}, Name: #{item.name}, Type: #{Cfg::ItemType.resolve(item.type)}"
    end

    # 遍历 (Iterate) Shops
    puts "--- Iterating Shops ---"
    tables.shops.data_list.each do |shop|
      puts "Shop ID: #{shop.shop_id}, Type: #{ Cfg::ShopType.resolve(shop.shop_type)}"
    end

    # 示例：查找 ID 为 12 的物品 (Example: Find Item with ID 12)
    item_12 = tables.items.data_list.find { |item| item.id == 12 }
    if item_12
      puts "Found Item 12: #{item_12.name}" 
    else
      puts "Item 12 not found"
    end

    puts "ITEM 1 name #{tables.item_map[1].name}"
    puts "ITEM 3 name #{tables.item_map[3].name}"

    tables.shop_type_map[:ShopType_DIAMOND_SHOP].each do |shop|
      puts "Shop ID: #{shop.shop_id}, Type: #{ Cfg::ShopType.resolve(shop.shop_type)}"
    end
  end
end

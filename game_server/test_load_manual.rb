begin
  require_relative 'config/pb_datas/cfg/schema_tables'
  puts "Schema tables loaded"
  
  data_dir = File.join(Dir.pwd, 'config/pb_datas/data')
  puts "Data dir: #{data_dir}"
  
  tables = Tables.new(data_dir)
  puts "Tables initialized"
  
  puts "Item Config: #{tables.item_config.class.name}"
  puts "Shop Config: #{tables.shop_config.class.name}"
rescue => e
  puts "Error: #{e.message}"
  puts e.backtrace
end

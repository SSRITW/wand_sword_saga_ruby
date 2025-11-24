require_relative './schema_pb'

class Tables
    attr_reader :items, :item_map, :shops, :shop_map, :shop_type_map

    def initialize(data_dir)
      Dir.glob(File.join(data_dir, '*.bytes')).each do |file|
        basename = File.basename(file, '.bytes')
        # item -> Item, shop -> Shop
        class_name = basename.split('_').map(&:capitalize).join
        if Cfg.const_defined?(class_name)
          klass = Cfg.const_get(class_name)
          content = File.binread(file)
          begin
            data = klass.decode(content)
            # item -> @items, shop -> @shops
            instance_variable_set("@#{basename}s", data)
            puts "Loaded Cfg::#{class_name} into @#{basename}s"
          rescue => e
            puts "Error loading #{basename}.bytes: #{e.message}"
          end
        else
          puts "Warning: Class Cfg::#{class_name} not found for file #{basename}.bytes"
        end
      end

      @item_map = Hash.new
      @items.data_list.each do |item|
        @item_map[item.id] = item
      end

      @shop_map = Hash.new
      @shops.data_list.each do |shop|
        @shop_map[shop.shop_id] = shop
      end

      @shop_type_map = Hash.new
      @shops.data_list.each do |shop|
        if @shop_type_map.key?(shop.shop_type) == false
          @shop_type_map[shop.shop_type] = []
        end
        @shop_type_map[shop.shop_type] << shop
      end
    end
end
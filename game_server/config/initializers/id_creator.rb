require_relative '../../app/lib/utils/id_creator'

module IdGenerator
  class << self

    def init
      player_id_creator_init
      item_id_creator_init
    rescue StandardError => e
      abort("FATAL: Failed to initialize IdGenerator: #{e.message}")
    end

    def next_player_id(show_server_id)
      @player_id_creators[show_server_id].next_id
    end

    def next_item_id
      @item_id_creator.next_id
    end

    private

    def player_id_creator_init
      @player_id_creators = Concurrent::Map.new
      max_ids_by_show_server = Player.group(:show_server_id).maximum(:player_id)
      max_ids_by_show_server.each do |show_server_id, max_player_id|
        @player_id_creators[show_server_id] = IdCreator.new(
          show_server_id,
          max_player_id || 0
        )
        Rails.logger.info "Created ID generator for show_server_id=#{show_server_id}, max_id=#{max_player_id}"
      end
      # 主サーバーidのクリエイター必ず存在する
      server_id = ENV.fetch("GAME_SERVER_ID", "1").to_i
      if @player_id_creators[server_id] == nil
        @player_id_creators[server_id]= IdCreator.new(server_id, 0)
      end
      Rails.logger.info "IdGenerator initialized max_player_ids=#{max_ids_by_show_server.to_json}"
    end

    def item_id_creator_init
      # TODO: 实现 item ID 生成器初始化
      @item_id_creator = nil
    end
  end
end

Rails.application.config.after_initialize do
  unless defined?(Rails::Console) || Rails.env.test?
    Rails.logger.info "IdGenerator initializing..."
    IdGenerator.init
    Rails.logger.info "IdGenerator initialized..."
  end
end
# frozen_string_literal: true

require_relative '../pb_datas/cfg/schema_tables'

# Initialize global game data tables
# Access via: GAME_TABLES.item_config
GAME_TABLES = Tables.new(File.join(File.dirname(__FILE__), '../pb_datas/data'))

# frozen_string_literal: true

require_relative '../pb_datas/cfg/schema_tables'

# Initialize global game config
GAME_TABLES = Tables.new(File.join(File.dirname(__FILE__), '../pb_datas/data'))

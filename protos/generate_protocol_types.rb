#!/usr/bin/env ruby
# frozen_string_literal: true

# プロトコルファイル自動生成スクリプト
# 機能：
#   1. protoc を使用して Ruby protobuf ファイル (msg_pb.rb) を生成
#   2. プロトコル ID マッピングファイル (protocol_types.rb) を自動生成
#
# 使い方: ruby protos/generate_protocol_types.rb

require 'fileutils'

# 設定
PROTO_FILE = File.expand_path('msg.proto', __dir__)
PROTO_DIR = File.dirname(PROTO_FILE)
GATEWAY_PROTOS_DIR = File.expand_path('../gateway/app/lib/protos', __dir__)
GAME_SERVER_PROTOS_DIR = File.expand_path('../game_server/app/lib/protos', __dir__)
GATEWAY_OUTPUT_FILE = File.join(GATEWAY_PROTOS_DIR, 'protocol_types.rb')
GAME_SERVER_OUTPUT_FILE = File.join(GAME_SERVER_PROTOS_DIR, 'protocol_types.rb')

# ID 範囲設定
S2C_START_ID = 1      # サーバー -> クライアント、1 から開始
C2S_START_ID = 1000   # クライアント -> サーバー、1000 から開始

def extract_messages(proto_content)
  s2c_messages = []
  c2s_messages = []

  # message 定義をマッチング
  proto_content.scan(/message\s+((?:S2C|C2S)_\w+)\s*\{/) do |match|
    message_name = match[0]

    if message_name.start_with?('S2C_')
      s2c_messages << message_name
    elsif message_name.start_with?('C2S_')
      c2s_messages << message_name
    end
  end

  { s2c: s2c_messages, c2s: c2s_messages }
end

def generate_constant_name(message_name)
  # S2C_VerifyToken -> S2C_VERIFY_TOKEN
  # C2S_Heartbeat -> C2S_HEARTBEAT
  message_name.gsub(/([a-z])([A-Z])/, '\1_\2').upcase
end

def generate_protocol_types(messages)
  s2c_messages = messages[:s2c]
  c2s_messages = messages[:c2s]

  # ID マッピング生成
  s2c_mapping = {}
  c2s_mapping = {}

  s2c_messages.each_with_index do |msg, index|
    s2c_mapping[msg] = S2C_START_ID + index
  end

  c2s_messages.each_with_index do |msg, index|
    c2s_mapping[msg] = C2S_START_ID + index
  end

  # コード生成
  code = <<~RUBY
    require_relative 'msg_pb'

    module SocketServer
      module ProtocolTypes
        # ========== サーバー -> クライアント (S2C) ==========
  RUBY

  # S2C 定数追加
  s2c_mapping.each do |msg_name, id|
    const_name = generate_constant_name(msg_name)
    code += "    #{const_name.ljust(30)} = #{id.to_s.rjust(4)}  # #{msg_name}\n"
  end

  code += "\n    # ========== クライアント -> サーバー (C2S) ==========\n"

  # C2S 定数追加
  c2s_mapping.each do |msg_name, id|
    const_name = generate_constant_name(msg_name)
    code += "    #{const_name.ljust(30)} = #{id.to_s.rjust(4)}  # #{msg_name}\n"
  end

  code += "\n    # プロトコル ID -> クラスマッピング\n"
  code += "    ID_TO_CLASS = {\n"

  # S2C マッピング
  s2c_mapping.each do |msg_name, id|
    const_name = generate_constant_name(msg_name)
    code += "      #{const_name.ljust(30)} => Protocol::#{msg_name},\n"
  end

  # C2S マッピング
  c2s_mapping.each do |msg_name, id|
    const_name = generate_constant_name(msg_name)
    code += "      #{const_name.ljust(30)} => Protocol::#{msg_name},\n"
  end

  code += "    }.freeze\n\n"

  # 逆マッピングとユーティリティメソッド生成
  code += <<~RUBY
        # クラス -> プロトコル ID マッピング
        CLASS_TO_ID = ID_TO_CLASS.invert.freeze

        # プロトコル ID から対応するクラスを取得
        # @param protocol_id [Integer]
        # @return [Class, nil]
        def self.get_class(protocol_id)
          ID_TO_CLASS[protocol_id]
        end

        # メッセージオブジェクトからプロトコル ID を取得
        # @param message [Google::Protobuf::MessageExts]
        # @return [Integer, nil]
        def self.get_id(message)
          CLASS_TO_ID[message.class]
        end

        # プロトコル ID が有効かチェック
        # @param protocol_id [Integer]
        # @return [Boolean]
        def self.valid_id?(protocol_id)
          ID_TO_CLASS.key?(protocol_id)
        end
      end
    end
  RUBY

  code
end

def generate_protobuf_ruby_file
  puts "\n========== ステップ 1: Ruby Protobuf ファイルを生成 =========="

  # 出力ディレクトリが存在することを確認
  FileUtils.mkdir_p(GATEWAY_PROTOS_DIR)
  FileUtils.mkdir_p(GAME_SERVER_PROTOS_DIR)

  # protoc コマンドを構築
  gateway_dir = File.expand_path('../gateway', __dir__)
  game_server_dir = File.expand_path('../game_server', __dir__)

  gateway_cmd = "cd \"#{gateway_dir}\" && bundle exec grpc_tools_ruby_protoc " \
        "--ruby_out=app/lib/protos " \
        "--grpc_out=app/lib/protos " \
        "--proto_path=../protos " \
        "../protos/msg.proto"

  game_server_cmd = "cd \"#{game_server_dir}\" && bundle exec grpc_tools_ruby_protoc " \
    "--ruby_out=app/lib/protos " \
    "--grpc_out=app/lib/protos " \
    "--proto_path=../protos " \
    "../protos/msg.proto"

  puts "コマンドを実行: #{gateway_cmd}"

  # コマンドを実行
  success = system(gateway_cmd)

  unless success
    puts "❌ エラー: protoc コンパイル失敗"
    exit 1
  end

  puts "コマンドを実行: #{game_server_cmd}"

  # コマンドを実行
  success = system(game_server_cmd)

  unless success
    puts "❌ エラー: protoc コンパイル失敗"
    exit 1
  end

  msg_pb_file = File.join(GATEWAY_PROTOS_DIR, 'msg_pb.rb')
  if File.exist?(msg_pb_file)
    puts "✅ 生成成功: #{msg_pb_file}"
  else
    puts "❌ エラー: msg_pb.rb ファイルが生成されませんでした"
    exit 1
  end

  game_msg_pb_file = File.join(GAME_SERVER_PROTOS_DIR, 'msg_pb.rb')
  if File.exist?(game_msg_pb_file)
    puts "✅ 生成成功: #{game_msg_pb_file}"
  else
    puts "❌ エラー: msg_pb.rb ファイルが生成されませんでした"
    exit 1
  end
end

# メインフロー
begin
  puts "=========================================="
  puts "    プロトコルファイル自動生成ツール"
  puts "=========================================="

  unless File.exist?(PROTO_FILE)
    puts "❌ エラー: proto ファイルが存在しません: #{PROTO_FILE}"
    exit 1
  end

  # ステップ 1: Ruby Protobuf ファイルを生成
  generate_protobuf_ruby_file

  # ステップ 2: メッセージ定義を解析してプロトコル ID を生成
  puts "\n========== ステップ 2: プロトコル ID マッピングファイルを生成 =========="
  puts "proto ファイルを読み込み: #{PROTO_FILE}"

  proto_content = File.read(PROTO_FILE)

  puts "メッセージ定義を解析..."
  messages = extract_messages(proto_content)

  puts "\n見つかったメッセージ:"
  puts "  S2C (サーバー -> クライアント): #{messages[:s2c].size} 個"
  messages[:s2c].each { |msg| puts "    - #{msg}" }

  puts "  C2S (クライアント -> サーバー): #{messages[:c2s].size} 個"
  messages[:c2s].each { |msg| puts "    - #{msg}" }

  puts "\nprotocol_types.rb を生成..."
  code = generate_protocol_types(messages)

  # 出力ディレクトリが存在することを確認
  FileUtils.mkdir_p(File.dirname(GATEWAY_OUTPUT_FILE))
  FileUtils.mkdir_p(File.dirname(GAME_SERVER_OUTPUT_FILE))

  # ファイルに書き込み
  File.write(GATEWAY_OUTPUT_FILE, code)
  File.write(GAME_SERVER_OUTPUT_FILE, code)

  puts "✅ 生成成功: #{GATEWAY_OUTPUT_FILE}, #{GAME_SERVER_OUTPUT_FILE}"
  puts "\nID 割り当て:"
  puts "  S2C: #{S2C_START_ID} ~ #{S2C_START_ID + messages[:s2c].size - 1}"
  puts "  C2S: #{C2S_START_ID} ~ #{C2S_START_ID + messages[:c2s].size - 1}"

  puts "\n=========================================="
  puts "✅ すべてのファイル生成完了！"
  puts "=========================================="
  puts "生成されたファイル："
  puts "  1. #{File.join(GATEWAY_PROTOS_DIR, 'msg_pb.rb')}, #{File.join(GAME_SERVER_PROTOS_DIR, 'msg_pb.rb')}"
  puts "  2. #{GATEWAY_OUTPUT_FILE}, #{GAME_SERVER_OUTPUT_FILE}"

rescue => e
  puts "\n=========================================="
  puts "❌ 生成失敗"
  puts "=========================================="
  puts "エラー: #{e.message}"
  puts e.backtrace.join("\n")
  exit 1
end
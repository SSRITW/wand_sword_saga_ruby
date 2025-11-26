class PlayerItemService
  def self.load_items(player_id)
    # PlayerSessionHelper を使用してプレイヤーデータを取得
    # 使用 PlayerSessionHelper 获取玩家数据
    result = PlayerSessionHelper.player_data_get(player_id)
    return result["code"] if result["code"] != Protocol::ErrorCode::SUCCESS

    player_data = result["player_data"]

    item_list = PlayerItem.find_by(player_id: player_id)
    item_data = Concurrent::Map.new

    item_list.each do |item|
      item_data[item.guid] = item
    end
    player_data.items = item_data

    return Protocol::ErrorCode::SUCCESS
  end

  # 全部のアイテムデータをクライアントに送信（loginする時に）
  def self.send_item_full_list(player_id)
    # オンラインプレイヤーデータを取得
    # 使用 PlayerSessionHelper 获取在线玩家数据
    result = PlayerSessionHelper.online_player_data_get(player_id)
    if result["code"] != Protocol::ErrorCode::SUCCESS
      return result["code"]
    end

    player_data = result["player_data"]

    # item list プロトコル構築
    item_list_msg = Protocol::S2C_ItemList.new(item_list: [])
    player_data.items.each do |guid, item|
      item_list_msg.item_list << item.to_proto
    end

    # クライアントに送信
    player_data.context.send_message(
      SocketServer::ProtocolTypes::S2C_ITEM_LIST,
      item_list_msg
    )
    Protocol::ErrorCode::SUCCESS
  end

  # アイテムの増加
  # TODO 重要なデータから、変更するLogを持久化・定着する必要がある
  # TODO トランザクション保護の必要を検討  /  考虑是否需要事务保护
  def self.add_item(player_data, item_list, reason, param)
    # 変更についての送信メッセージ
    item_list_msg = Protocol::S2C_ItemList.new(item_list: [])

    new_item_list = []

    # 事前に追加アイテムを合併し
    add_item_list = PlayerItem.merge_item(item_list)


    player_data.with_lock do

      add_item_list.each do |award|
        item_config = GAME_TABLES.item_map[award.id]
        if item_config == nil
          Rails.logger.error "itemが存在しない:player_id=#{player_data.player_id} award.item_id=#{award.id},reason=#{reason},param=#{param} "
          return Protocol::ErrorCode::CONFIG_ITEM_ID_NOT_EXIST
        end

        # 特別のレベルアップ処理
        if award.id == Constants::ITEM::EXP
          now_exp = 0
          exp_item = player_data.items.values.select { |item| item.item_id == award.id}
          exp_item.each do |item|
            now_exp += item.count
          end

          add_num = PlayerLevelService.level_up_check_and_update(player_data, award.count+now_exp)
          if exp_item.empty?
            new_item = PlayerItem.new(
              player_id: player_data.player_id,
              guid: IdGenerator.next_item_id,
              item_id: award.id,
              count: add_num,
              is_new: item_config.new_mark
            )
            player_data.items[new_item.guid] = new_item
            new_item_list << new_item
            item_list_msg.item_list << new_item.to_proto
          else
            exp_item[0].count = add_num
            exp_item[0].update(count: add_num)
            item_list_msg.item_list << exp_item[0].to_proto
          end

          next
        end

        add_num = award.count

        # スタック処理 / 处理堆叠
        # 同じitem_idで堆叠未満のアイテムを筛选し、数量の多い順にソート
        # 筛选相同 item_id 且未堆叠满的格子，并按数量降序排序
        not_full_items = player_data.items.values
                                    .select { |item| item.item_id == award.id && (item_config.stack_limit == 0 || item.count < item_config.stack_limit) }
                                    .sort_by { |item| -item.count }  # 数量の多い順 / 降序排序

        # 未満のアイテムに追加
        not_full_items.each do |item|
          if item_config.stack_limit == 0 || item.count+add_num <= item_config.stack_limit
            item.count += add_num
            add_num = 0
          else
            add_num -= item_config.stack_limit - item.count
            item.count = item_config.stack_limit
          end
          item.update(count: item.count)
          item_list_msg.item_list << item.to_proto

          break if add_num <= 0
        end

        # 新アイテム追加
        while add_num > 0 do
          new_item = PlayerItem.new(
            player_id: player_data.player_id,
            guid: IdGenerator.next_item_id,
            item_id: award.id,
            is_new: item_config.new_mark
          )

          if item_config.stack_limit > 0 && item_config.stack_limit < add_num
            add_num -= item_config.stack_limit
            new_item.count = item_config.stack_limit
          else
            new_item.count = add_num
            add_num = 0
          end
          # メモリに追加
          player_data.items[new_item.guid] = new_item

          item_list_msg.item_list << new_item.to_proto
          new_item_list << new_item
        end

        Rails.logger.info "[#{player_data.player_id}|#{player_data.
          player.nickname}] use item:[#{award.id}|#{award.count}, reason:#{reason}, param:#{param}"
      end

      # 新アイテムを実際dbに保存
      if new_item_list.any?
        new_items_data = new_item_list.map do |item|
          {
            player_id: item.player_id,
            guid: item.guid,
            item_id: item.item_id,
            count: item.count,
            is_new: item.is_new
          }
        end
        PlayerItem.insert_all(new_items_data)
      end
    end

    # クライアントに送信
    player_data.context.send_message(
      SocketServer::ProtocolTypes::S2C_ITEM_LIST,
      item_list_msg
    )

    Protocol::ErrorCode::SUCCESS
  end


  # アイテム listが足りるかどうかを検証
  def self.check_items_enough(player_data, check_item_list)
    # 事前に追加アイテムを合併し
    check_list = PlayerItem.merge_item(check_item_list)

    check_list.each do |check_item|
      if check_item.count <= 0
        return Protocol::ErrorCode::ITEM_NUM_ILLEGAL
      end

      need_num = check_item.count
      item_list = player_data.items.values.select { |item| item.item_id == check_item.id }

      item_list.each do |item|
        need_num -= item.count
        break if need_num <= 0
      end

      return Protocol::ErrorCode::ITEM_NOT_ENOUGH if need_num > 0
    end

    return Protocol::ErrorCode::SUCCESS
  end

  # アイテムが足りるかどうかを検証
  def self.check_item_enough(player_data, check_item_id, check_item_num)

    return Protocol::ErrorCode::ITEM_ID_ILLEGAL if check_item_id <= 0
    return Protocol::ErrorCode::ITEM_NUM_ILLEGAL if check_item_num <= 0

    item_list = player_data.items.values.select { |item| item.item_id == check_item_id }

    item_list.each do |item|
      check_item_num -= item.count
      break if check_item_num <= 0
    end

    return check_item_num > 0 ? Protocol::ErrorCode::ITEM_NOT_ENOUGH : Protocol::ErrorCode::SUCCESS
  end

  # アイテムlistの消耗
  def self.use_items(player_data, item_list, reason, param)
    # 変更についての送信メッセージ
    item_list_msg = Protocol::S2C_ItemList.new(item_list: [])

    code = check_items_enough(player_data, item_list)
    return code if code != Protocol::ErrorCode::SUCCESS
    # 事前にアイテムを合併し
    use_items = PlayerItem.merge_item(item_list)

    player_data.with_lock do
      use_items.each do |item|
        item_list_msg.item_list.concat(use_item_private(player_data, item.id, item.count, reason, param))
      end
    end

    # クライアントに送信
    player_data.context.send_message(
      SocketServer::ProtocolTypes::S2C_ITEM_LIST,
      item_list_msg
    )

    return Protocol::ErrorCode::SUCCESS
  end

  # アイテムの消耗
  def self.use_item(player_data, item_id, item_num, reason, param)

    code = check_item_enough(player_data, item_id, item_num)
    return code if code != Protocol::ErrorCode::SUCCESS
    msg = Protocol::S2C_ItemList.new(item_list: [])
    player_data.with_lock do
      msg.item_list.concat(use_item_private(player_data, item_id, item_num, reason, param))
    end

    # クライアントに送信
    player_data.context.send_message(
      SocketServer::ProtocolTypes::S2C_ITEM_LIST,
      msg
    )

    return Protocol::ErrorCode::SUCCESS
  end


  private
  # ここでは、ロックを使用しないため、アクセスする箇所にロックをかける必要があります。
  def self.use_item_private(player_data, item_id, item_num, reason, param)
    item_list = player_data.items.values
                           .select { |item| item.item_id == item_id }
                           .sort_by { |item| -item.count }  # 数量の多い順 / 降序排序
    change_item_msg_list = []

    item_list.each do |item|
      if item.count < item_num
        item_num -= item.count
        item.count = 0
        # メモリに削除
        player_data.items.delete(item.guid)
        # dbに削除
        item.destroy
      else
        item.count -= item_num
        item.update(count: item.count)
        item_num = 0
      end
      change_item_msg_list << item.to_proto
      break if item_num <= 0
    end

    Rails.logger.info "[#{player_data.player_id}|#{player_data.
      player.nickname}] use item:[#{item_id}|#{item_num}, reason:#{reason}, param:#{param}"

    return change_item_msg_list
  end
end
class Snowflake
  attr_reader :start_time, :worker_id_bits, :sequence_bits

  def initialize(worker_id, worker_id_bits = 5, sequence_bits = 12)
    @start_time = Time.new(2025, 1, 1).to_i * 1000  # 设置起始时间戳，单位为毫秒 / 開始タイムスタンプを設定、単位はミリ秒
    @worker_id = worker_id  # 工作机器ID / ワーカーマシンID
    @worker_id_bits = worker_id_bits  # 工作机器ID的位数 / ワーカーマシンIDのビット数
    @sequence_bits = sequence_bits  # 序列号的位数 / シーケンス番号のビット数
    @max_worker_id = (1 << worker_id_bits) - 1  # 最大工作机器ID / 最大ワーカーマシンID
    @max_sequence = (1 << sequence_bits) - 1  # 最大序列号 / 最大シーケンス番号
    @last_timestamp = 0  # 上次生成ID的时间戳 / 前回ID生成時のタイムスタンプ
    @sequence = 0  # 序列号 / シーケンス番号
  end

  def generate_id
    timestamp = current_timestamp

    if timestamp < @last_timestamp
      raise "Clock moved backwards. Refusing to generate ID for #{last_timestamp - timestamp} milliseconds."
    end

    if timestamp == @last_timestamp
      @sequence = (@sequence + 1) & @max_sequence
      if @sequence.zero?
        timestamp = til_next_millis(@last_timestamp)
      end
    else
      @sequence = 0
    end

    @last_timestamp = timestamp

    ((timestamp - start_time) << (@worker_id_bits + @sequence_bits)) |
      (@worker_id << @sequence_bits) |
      @sequence
  end

  private

  def current_timestamp
    (Time.now.to_f * 1000).to_i  # 获取当前时间戳，单位为毫秒 / 現在のタイムスタンプを取得、単位はミリ秒
  end

  def til_next_millis(last_timestamp)
    timestamp = current_timestamp
    while timestamp <= last_timestamp
      timestamp = current_timestamp
    end
    timestamp
  end
end
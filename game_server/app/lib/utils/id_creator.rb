class IdCreator

  # worker_idを65,535以下の数値に設定する必要があり
  # 281474976710656個idが使える
  def initialize(worker_id, now_id)
    raise ArgumentError, "worker_id must be between 0 and 4095" unless worker_id.between?(0, 4095)
    @worker_id = worker_id
    @now_id = calculate_initial_id(now_id)
    @mutex = Mutex.new
  end

  def next_id
    @mutex.synchronize do
      @now_id+=1
      return @now_id
    end
  end

  private
  def calculate_initial_id(now_id)
    if now_id && now_id > 0
      now_id
    else
      @worker_id << 48
    end
  end

end
require_relative '../../app/lib/utils/snow_flake'

module IdGenerator
  class << self
    attr_reader :snowflake

    def generate_id
      @snowflake.generate_id
    end
  end
end

Rails.application.config.after_initialize do
  Rails.logger.info "SnowFlake ID Generator initializing..."

  worker_id = ENV.fetch('SNOWFLAKE_WORKER_ID', 1).to_i
  IdGenerator.instance_variable_set(:@snowflake, Snowflake.new(worker_id))

  Rails.logger.info "SnowFlake initialized with worker_id: #{worker_id}"
end
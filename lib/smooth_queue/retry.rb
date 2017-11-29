module SmoothQueue
  Retry = Struct.new(:message_id) do
    include Redix::Connection

    def handle
      if should_retry?
        payload['retry_count'] = retry_count + 1
        Redix.retry(id, payload, retry_delay)
      else
        SmoothQueue.config.retries_exhausted_handler.call(payload)
      end
    end

    private

    def retry_count
      payload.fetch('retry_count', 0)
    end

    def retry_delay
      delay = SmoothQueue.config.retry_delay
      if delay.is_a?(Numeric)
        delay
      else
        delay.call(retry_count, payload)
      end
    end

    def should_retry?
      retry_count < SmoothQueue.config.max_retries
    end

    def message
      payload.fetch('message')
    end

    def payload
      @payload ||= with_nredis do |redis|
        Util.from_json(redis.hget('messages', message_id))
      end
    end
  end
end

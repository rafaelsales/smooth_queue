module SmoothQueue
  class RedisHelpers
    SCRIPTS = {
      pop_message_to_process: {
        script: <<-LUA.freeze,
          local queue = KEYS[1]
          local processing_queue = KEYS[2]
          local max_concurrency = KEYS[3]

          if redis.call('LLEN', processing_queue) < tonumber(max_concurrency) then
            local id = redis.call('RPOPLPUSH', queue, processing_queue)
            return id
          else
            return nil
          end
        LUA
      }
    }

    def self.pop_message_to_process(queue, processing_queue, max_concurrency)
      call(:pop_message_to_process, keys: [queue, processing_queue, max_concurrency])
    end

    def self.call(name, keys: [], args: [])
      SmoothQueue.with_redis do |redis|
        redis.evalsha(script_sha(name), keys, args)
      end
    rescue Redis::CommandError => e
      if e.message =~ /NOSCRIPT/
        script_sha(name, reload: true)
        retry
      else
        raise
      end
    end

    def self.script_sha(name, reload: false)
      SmoothQueue.with_redis do |redis|
        if hash.key?(:sha) || reload
          hash[:sha] = redis.script(:load, hash.fetch(:script))
        end
        hash.fetch(:sha)
      end
    end
  end
end

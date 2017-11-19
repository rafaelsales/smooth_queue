module SmoothQueue
  class RedisHelpers
    class Script < Struct.new(:code)
      def call(keys: [], args: [])
        SmoothQueue.with_nredis do |redis|
          redis.evalsha(sha, keys, args)
        end
      rescue Redis::CommandError => e
        if e.message =~ /NOSCRIPT/
          load_script
          retry
        else
          raise
        end
      end

      def load_script
        SmoothQueue.with_redis do |redis|
          @sha = redis.script(:load, code).freeze
        end
      end

      def sha
        load_script unless @sha
        @sha
      end
    end

    SCRIPTS = {
      pop_message_to_process: Script.new(<<-LUA.freeze),
        local queue = KEYS[1]
        local processing_queue = KEYS[2]
        local max_concurrency = ARGV[1]

        if redis.call('LLEN', processing_queue) < tonumber(max_concurrency) then
          local id = redis.call('RPOPLPUSH', queue, processing_queue)
          return id
        else
          return nil
        end
      LUA
    }.freeze

    def self.pop_message_to_process(queue, processing_queue, max_concurrency)
      call(:pop_message_to_process, keys: [queue, processing_queue], args: [max_concurrency])
    end

    def self.call(name, **arguments)
      SCRIPTS.fetch(name).call(**arguments)
    end
  end
end

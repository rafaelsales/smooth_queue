module SmoothQueue
  module Redix
    module Connection
      def self.redis_connection_pool
        @redis_connection_pool ||= ConnectionPool::Wrapper.new(size: 10) { Redis.new }
      end

      def with_nredis(&_block)
        with_redis { |redis| yield(Redis::Namespace.new(REDIS_NS, redis: redis)) }
      end

      def with_redis(&block)
        Connection.redis_connection_pool.with(&block)
      end
    end

    Script = Struct.new(:code) do
      def call(keys: [], args: [])
        SmoothQueue.with_nredis do |redis|
          redis.evalsha(sha, keys, args)
        end
      rescue Redis::CommandError => e
        raise unless e.message =~ /NOSCRIPT/
        load_script
        retry
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

    extend Connection

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

    def self.pop_message_to_process(queue)
      processing_queue = SmoothQueue.config.processing_queue(queue)
      max_concurrency = SmoothQueue.config.max_concurrency(queue)
      call_script(:pop_message_to_process, keys: [queue, processing_queue], args: [max_concurrency])
    end

    def self.enqueue(queue, id, payload, &_block)
      with_nredis do |redis|
        redis.multi do
          redis.sadd('queues', queue)
          redis.hset('messages', id, payload)
          redis.lpush(queue, id)
          redis.publish('queue_changed', queue)
          yield(redis) if block_given?
        end
      end
    end

    def self.processing_done(queue, id)
      processing_queue = SmoothQueue.config.processing_queue(queue)
      with_nredis do |redis|
        redis.multi do
          redis.lrem(processing_queue, 1, id)
          redis.publish('queue_changed', queue)
        end
      end
    end

    def self.retry(queue, id, payload)
      enqueue(queue, id, payload) do |redis|
        redis.lrem(processing_queue, 1, id)
      end
    end

    def self.queue_updated(queue)
      with_nredis do |redis|
        if pop_message_to_process(queue)
          payload = Util.from_json(redis.hget('messages', id))
          message = payload.delete('message')
          config.queue_handler.call(id, message, payload)
        end
      end
    end

    def self.call_script(name, **arguments)
      SCRIPTS.fetch(name).call(**arguments)
    end
  end
end

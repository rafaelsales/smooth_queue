module SmoothQueue
  # Redis interface with functions built for SmoothQueue
  module Redix
    module Connection
      def self.redis_connection_pool
        @redis_connection_pool ||= ConnectionPool.new { checkout_redis }
      end

      def self.checkout_redis
        Redis.new
      end

      def self.checkout_nredis(redis = Redis.new)
        Redis::Namespace.new(REDIS_NS, redis: redis)
      end

      def with_nredis(&_block)
        with_redis { |redis| yield(Connection.checkout_nredis(redis)) }
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
        load
        retry
      end

      def sha
        load unless defined?(@sha)
        @sha
      end

      def load
        SmoothQueue.with_redis do |redis|
          @sha = redis.script(:load, code).freeze
        end
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

    def self.pop_message_to_process(queue_name)
      queue = SmoothQueue.config.queue(queue_name)
      call_script(
        :pop_message_to_process,
        keys: [queue_name, queue.processing_queue_name],
        args: [queue.max_concurrency],
      )
    end

    def self.enqueue(queue, id, payload, &_block)
      with_nredis do |redis|
        redis.multi do
          redis.sadd('queues', queue)
          redis.hset('messages', id, payload)
          redis.lpush(queue, id)
          yield(redis) if block_given?
        end
      end
    end

    def self.processing_done(queue_name, id)
      queue = SmoothQueue.config.queue(queue_name)
      with_nredis do |redis|
        redis.multi do
          redis.lrem(queue.processing_queue_name, 1, id)
          redis.hdel('messages', id)
        end
      end
    end

    def self.retry(queue_name, id, retry_at)
      queue = SmoothQueue.queue(queue_name)
      with_nredis do |redis|
        redis.multi do
          redis.zadd('retry', id, retry_at)
          redis.lrem(queue.processing_queue_name, 1, id)
        end
      end
    end

    def self.pick_message(queue_name)
      id = pop_message_to_process(queue_name)
      return unless id

      with_nredis do |redis|
        [id, redis.hget('messages', id)]
      end
    end

    def self.wait_for_messages
      redis = Connection.checkout_nredis
      redis.subscribe('queue_changed') do |on|
        on.message do |_channel, queue_name|
          pick_message(queue_name)
        end
      end
    end

    def self.call_script(name, **args)
      SCRIPTS.fetch(name).call(**args)
    end
  end
end

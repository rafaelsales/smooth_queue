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
    extend Connection

    Script = Struct.new(:code) do
      def call(keys: [], args: [])
        Redix.with_nredis do |redis|
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

    REDIS_NS = 'squeue'.freeze
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
      pop_retries_to_enqueue: Script.new(<<-LUA.freeze),
        local retry_queue = KEYS[1]
        local key_prefix = ARGV[1] .. ':'
        local cut_off_time = ARGV[2]
        local limit = 100
        local entries = redis.call('ZRANGEBYSCORE', retry_queue, 0, cut_off_time, 'LIMIT', 0, limit)
        local count = table.getn(entries)

        if count > 0 then
          for _, entry in pairs(entries) do
            -- A retry entry is a string with format 'queue_name/message_id'
            local separator_index = string.find(entry, '/')
            local target_queue = string.sub(entry, 0, separator_index - 1)
            local id = string.sub(entry, separator_index + 1)

            redis.call('LPUSH', key_prefix .. target_queue, id)
          end
          redis.call('ZREM', retry_queue, unpack(entries))
        end
        return count
      LUA
    }.freeze

    def self.pop_message_to_process(queue_name)
      queue = SmoothQueue.queue(queue_name)
      call_script(
        :pop_message_to_process,
        keys: [queue_name, queue.processing_queue_name],
        args: [queue.max_concurrency],
      )
    end

    def self.pop_retries_to_enqueue(cut_off_time: Time.now)
      call_script(
        :pop_retries_to_enqueue,
        keys: [RETRY_QUEUE],
        args: [REDIS_NS, cut_off_time.to_i],
      )
    end

    def self.enqueue(queue_name, id, payload, &_block)
      with_nredis do |redis|
        redis.multi do
          redis.sadd('queues', queue_name)
          redis.hset('messages', id, payload)
          redis.lpush(queue_name, id)
          yield(redis) if block_given?
        end
      end
    end

    def self.processing_done(queue_name, id)
      queue = SmoothQueue.queue(queue_name)
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
          redis.zadd(RETRY_QUEUE, retry_at, "#{queue_name}/#{id}")
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

    def self.call_script(name, **args)
      SCRIPTS.fetch(name).call(**args)
    end
  end
end

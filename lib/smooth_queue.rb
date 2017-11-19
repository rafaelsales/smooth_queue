require 'redis'
require 'redis-namespace'
require 'connection_pool'
require_relative 'smooth_queue/config'
require_relative 'smooth_queue/util'
require_relative 'smooth_queue/redis_helpers'

module SmoothQueue
  PRIORITIES = %i[head tail].freeze
  REDIS_NS = 'squeue'.freeze

  def self.configure(&_block)
    @config ||= Config.new
    yield config
  end

  def self.config
    @config
  end

  def self.wait_for_work
    with_nredis do |redis|
      redis.subscribe('queue_changed') do |on|
        on.message do |_channel, queue|
          puts redis.llen(processing_queue)
          queue_changed(queue, redis)
        end
      end
    end
  end

  def self.queue_changed(queue)
    max_concurrency = config.queue_max_concurrency(queue)
    processing_queue = Util.processing_queue(queue)

    with_nredis do |redis|
      binding.pry
      # TODO: Use lua to make next two lines atomic
      if redis.llen(processing_queue) < max_concurrency
        id = redis.rpoplpush(queue, processing_queue)
        payload = Util.from_json(redis.hget('messages', id))
        message = payload.delete('message')
        config.queue_handler.call(id, message, payload)
      end
    end
  end
  private_class_method :queue_changed

  # Enqueue the message in the given queue. The message can be added to the tail or to the head according to what
  # is specified in the priority argument
  def self.enqueue(queue, message, priority = :tail)
    if !message.is_a?(String) && !message.is_a?(Hash)
      raise ArgumentError, "`message` must be a String or Hash but was #{message.class}"
    end
    raise ArgumentError "`queue` #{queue} if not configured" unless config.queue_defined?(queue)

    payload = Util.build_message_payload(queue, message)
    id = Util.generate_id
    with_nredis do |redis|
      redis.sadd('queues', queue)
    end
    add_payload_to_queue(id, payload, queue)
  end

  # Removes the message from processing queue as it was successfully processed
  def self.done(id)
    with_nredis do |redis|
      payload = Util.from_json(redis.hget('messages', id))
      raise ArgumentError, "`id` doesn't match an existing message" unless payload

      queue = payload['queue']
      processing_queue = Util.processing_queue(queue)

      redis.multi do
        redis.lrem(processing_queue, 1, id)
        redis.publish('queue_changed', queue)
      end
    end
  end

  # Moves the message back to the waiting queue
  # NOTE: Redesign to support retry delay
  def self.retry(id)
    with_nredis do |redis|
      payload = Util.from_json(redis.hget('messages', id))
    end
    payload['retry_count'] = payload.fetch('retry_count', 0) + 1
    queue = payload['queue']
    processing_queue = Util.processing_queue(queue)

    add_payload_to_queue(id, payload, queue) do |redis|
      redis.lrem(processing_queue, 1, id)
    end
  end

  def self.redis_connection_pool
    @redis_connection_pool ||= ConnectionPool::Wrapper.new(size: 10) { Redis.new }
  end

  def self.with_redis(&block)
    redis_connection_pool.with(&block)
  end

  def self.with_nredis(&_block)
    with_redis { |redis| yield(Redis::Namespace.new(REDIS_NS, redis: redis)) }
  end

  def self.add_payload_to_queue(id, payload, queue, &_block)
    with_nredis do |redis|
      redis.multi do
        redis.hset('messages', id, payload)
        redis.lpush(queue, id)
        redis.publish('queue_changed', queue)
        yield(redis) if block_given?
      end
    end
  end
  private_class_method :add_payload_to_queue
end

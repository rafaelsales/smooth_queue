require 'redis'
require 'redis-namespace'
require 'connection_pool'
require_relative 'smooth_queue/config'
require_relative 'smooth_queue/util'
require_relative 'smooth_queue/redix'

module SmoothQueue
  extend Redix::Connection

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
          max_concurrency = config.queue_max_concurrency(queue)
          processing_queue = Util.processing_queue(queue)
          Redix.queue_updated(queue, processing_queue, max_concurrency)
        end
      end
    end
  end

  # Enqueue the message in the given queue. The message can be added to the tail or to the head according to what
  # is specified in the priority argument
  def self.enqueue(queue, message, priority = :tail)
    if !message.is_a?(String) && !message.is_a?(Hash)
      raise ArgumentError, "`message` must be a String or Hash but was #{message.class}"
    end
    raise ArgumentError "`queue` #{queue} if not configured" unless config.queue_defined?(queue)

    payload = Util.build_message_payload(queue, message)
    id = Util.generate_id
    Redix.enqueue(queue, id, payload)
  end

  # Removes the message from processing queue as it was successfully processed
  def self.done(id)
    with_nredis do |redis|
      payload = Util.from_json(redis.hget('messages', id))
      raise ArgumentError, "`id` doesn't match an existing message" unless payload

      queue = payload['queue']
      processing_queue = Util.processing_queue(queue)

      Redix.processing_done(queue, processing_queue, id)
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

    Redix.retry(queue, id, payload)
  end
end

require 'redis'
require 'redis-namespace'
require 'connection_pool'
require_relative 'smooth_queue/config'
require_relative 'smooth_queue/util'
require_relative 'smooth_queue/redix'

module SmoothQueue
  extend Redix::Connection

  REDIS_NS = 'squeue'.freeze

  def self.configure(&_block)
    @config ||= Config.new
    yield config
  end

  def self.config
    @config
  end

  def self.wait_for_work
    config.queues.each do |queue|
      Redix.queue_updated(queue.name)
    end

    redis = Redix::Connection.checkout_nredis
    redis.subscribe('queue_changed') do |on|
      on.message do |_channel, queue_name|
        Redix.queue_updated(queue_name)
      end
    end
  end

  # Enqueue the message in the given queue
  def self.enqueue(queue_name, message)
    if !message.is_a?(String) && !message.is_a?(Hash)
      raise ArgumentError, "`message` must be a String or Hash but was #{message.class}"
    end
    raise ArgumentError "`queue` #{queue_name} if not configured" unless config.valid_queue?(queue_name)

    payload = Util.build_message_payload(queue_name, message)
    id = Util.generate_id
    Redix.enqueue(queue_name, id, Util.to_json(payload))
  end

  # Removes the message from processing queue as it was successfully processed
  def self.done(id)
    with_nredis do |redis|
      payload = Util.from_json(redis.hget('messages', id))
      raise ArgumentError, "`id` doesn't match an existing message" unless payload

      Redix.processing_done(payload['queue'], id)
    end
  end

  # Moves the message back to the waiting queue
  # NOTE: Redesign to support retry delay
  def self.retry(id)
    payload = with_nredis do |redis|
      Util.from_json(redis.hget('messages', id))
    end
    payload['retry_count'] = payload.fetch('retry_count', 0) + 1
    Redix.retry(payload['queue'], id, payload)
  end
end

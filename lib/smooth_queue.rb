Bundler.require(:runtime_dependencies)
require 'redis'
require 'redis-namespace'
require 'connection_pool'
require_relative 'smooth_queue/config'
require_relative 'smooth_queue/util'
require_relative 'smooth_queue/redix'
require_relative 'smooth_queue/retry'

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

  def self.backfill!
    config.queues.each do |name|
      queue.max_concurrency.times do
        handle_next_message(name)
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
    handle_next_message(queue_name)
  end

  # Remove the message from processing queue as it was successfully processed
  def self.done(id)
    with_nredis do |redis|
      payload = Util.from_json(redis.hget('messages', id))
      raise ArgumentError, "`id` doesn't match an existing message" unless payload
      queue_name = payload['queue']
      Redix.processing_done(queue_name, id)
      handle_next_message(queue_name)
    end
  end

  # Take a next message from queue and move to processing queue if the concurrency is not maxed out
  def self.handle_next_message(queue_name)
    id, json_payload = Redix.pick_message(queue_name)
    return unless json_payload
    payload = Util.from_json(json_payload)
    message = payload.delete('message')
    SmoothQueue.config.queue(queue_name).handle(id, message, payload)
  end

  # Move the message back to the waiting queue
  # NOTE: Redesign to support retry delay
  def self.retry(id)
    Retry.new(id).handle
  end

  def self.stats
    with_nredis do |redis|
      config.queues.each_with_object({}) do |(name, queue), hash|
        hash[queue.name] = {
          waiting: redis.llen(name),
          processing: redis.llen(queue.processing_queue_name),
        }
      end
    end
  end
end

require 'redis'
require 'redis-namespace'
require 'smooth_queue/configuration'

module SmoothQueue
  PRIORITIES = %i(head tail)

  def self.configure(&block)
    @config ||= Config.new
    yield config
  end

  def self.config
    @config
  end

  def self.wait_for_work
    redis.subscribe(:queue_changed) do |on|
      on.message do |_channel, queue|
        max_concurrency = config.queue_max_concurrency(queue)
        processing_queue = Util.processing_queue(queue)

        # TODO: Use lua to make next two lines atomic
        if redis.llen(processing_queue) < max_concurrency
          id = redis.rpoplpush(queue, processing_queue)
          payload = Util.from_json(redis.hget('messages', id))
          message = payload.delete('message')
          config.queue_handler.call(id, message, payload)
        end
      end
    end
  end

  # Enqueue the message in the given queue. The message can be added to the tail or to the head according to what
  # is specified in the priority argument
  def self.enqueue(queue, message, priority = :tail)
    raise ArgumentError, "`priority` must be #{PRIORITIES.inspect}, but was #{priority}" unless priority.in?(PRIORITIES)
    if !message.is_a?(String) && !message.is_a?(Hash)
      raise ArgumentError, "`message` must be a String or Hash but was #{message.class}"
    end
    raise ArgumentError, "`queue` must be a String but was #{queue.class}" unless message.is_a?(String)

    payload = Util.build_message_payload(queue, message)
    id = Util.generate_id
    redis.sadd('queues', queue)
    redis.multi do
      redis.hset('messages', id, Util.to_json(payload))
      redis.lpush(queue, id)
      redis.publish('queue_changed', queue)
    end
  end

  # Removes the message from processing queue as it was successfully processed
  def self.done(id)
    payload = Util.from_json(redis.hget('messages', id))
    raise ArgumentError, "`id` doesn't match an existing message" unless payload

    processing_queue = Util.processing_queue(payload['queue'])
    redis.lrem(processing_queue, 1, id)
  end

  # Moves the message back to the waiting queue
  # NOTE: Redesign to support retry delay
  def self.retry(id, priority = :tail)
    payload = Util.from_json(redis.hget('messages', id))
    payload['retry_count'] = payload.fetch('retry_count', 0) + 1
    queue = payload['queue']
    processing_queue = Util.processing_queue(queue)

    redis.multi do
      if priority == :head
        redis.rpush(queue, id)
      else
        redis.lpush(queue, id)
      end
      redis.lrem(processing_queue, 1, id)
      redis.hset('messages', id, payload)
    end
  end

  def self.redis
    @redis ||= Redis::Namespace.new('smooth_queue', redis: Redis.new)
  end
end

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

  # Enqueue the message in the given queue. The message can be added to the tail or to the head according to what
  # is specified in the priority argument
  def self.enqueue(queue, message, priority = :tail)
    raise ArgumentError, "`priority` must be #{PRIORITIES.inspect}, but was #{priority}" unless priority.in?(PRIORITIES)
    raise ArgumentError, "`message` must be a String but was #{message.class}" unless message.is_a?(String)
    raise ArgumentError, "`queue` must be a String but was #{queue.class}" unless message.is_a?(String)

    payload = Util.build_message_payload(queue, message)
    redis.sadd('queues', queue)
    redis.multi do
      redis.lpush(queue, Util.to_json(payload))
      redis.publish('queue_changed', queue)
    end
  end

  def self.wait_for_work
    redis.subscribe(:queue_changed) do |on|
      on.message do |_channel, message|
        payload = Util.from_json(message)
        max_concurrency = config.queue_max_concurrency(payload['queue'])
        processing_queue = config.processing_queue_name(queue)

        # TODO: Use lua to make this atomic
        if redis.llen(max_concurrency)
          redis.rpoplpush(queue, processing_queue)
          queue_options[:handler].call
        end
      end
    end
  end

  def self.done(json_message_info, priority = :tail)
    message_info = Util.from_json(json_message_info)
    message_info[queue]
  end

  def self.retry(message_info, priority = :tail)
  end

  def self.redis
    @redis ||= Redis::Namespace.new('smooth_queue', redis: Redis.new)
  end
end

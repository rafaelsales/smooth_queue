module SmoothQueue
  class Config
    DEFAULT_OPTIONS = {
      queues: {},
    }.freeze
    attr_reader :options

    def initialize
      @options = DEFAULT_OPTIONS.dup
    end

    def add_queue(queue, max_concurrency, &handler)
      options[:queues][queue.to_sym] = {
        max_concurrency: max_concurrency,
        handler: handler,
      }
    end

    def queue_max_concurrency(queue)
      options.dig(:queues, queue.to_sym, :max_concurrency)
    end

    def queue_handler(queue)
      options.dig(:queues, queue.to_sym, :handler)
    end

    def processing_queue(queue)
      @processing_queues ||= {}
      @processing_queues.fetch(queue) do
        "#{queue}-processing".freeze
      end
    end

    def queue_defined?(queue)
      options[:queues].key?(queue.to_sym)
    end
  end
end

module SmoothQueue
  class Config
    DEFAULT_OPTIONS = {
      queues: {}
    }.freeze
    attr_reader :options

    def iniailize
      @options = DEFAULT_OPTIONS.dup
    end

    def add_queue(queue, max_concurrency, &handler)
      options[:queues][queue.freeze] = {
        max_concurrency: max_concurrency,
        handler: handler,
      }
    end

    def queue_max_concurrency(queue)
      options.dig(:queues, queue, :max_concurrency)
    end

    def queue_handler
      options.dig(:queues, queue, :handler)
    end

    def processing_queue_name(queue)
      "#{queue}-processing"
    end
  end
end

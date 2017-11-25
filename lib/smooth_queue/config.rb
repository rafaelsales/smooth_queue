module SmoothQueue
  class Config
    Queue = Struct.new(:name, :max_concurrency, :handler) do
      def processing_queue_name
        @processing_queue_name ||= "#{name}-processing"
      end

      def handle(*args)
        handler.call(*args)
      end
    end

    DEFAULT_OPTIONS = {
      queues: {},
    }.freeze
    attr_reader :options

    def initialize
      @options = DEFAULT_OPTIONS.dup
    end

    def add_queue(queue_name, max_concurrency, &handler)
      options[:queues][queue_name.to_s] = Queue.new(queue_name.to_s, max_concurrency, handler)
    end

    def queue(queue_name)
      options.dig(:queues, queue_name.to_s)
    end

    def queues
      options[:queues].values
    end

    def valid_queue?(queue_name)
      options[:queues].key?(queue_name.to_s)
    end
  end
end

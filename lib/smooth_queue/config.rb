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

    attr_reader :queues, :retry_delay, :retries_exhausted_handler

    def initialize
      @queues = {}
    end

    # Define a queue
    #
    # @param [String] queue_name
    # @param [Integer] max_concurrency number of messages allowed to be processed simultaneously
    # @yield [id, message] called when a message is ready for processing. Make sure this block runs in O(1)
    def add_queue(queue_name, max_concurrency, &handler)
      queues[queue_name.to_s] = Queue.new(queue_name.to_s, max_concurrency, handler)
    end

    # Define global retry delay
    #
    # @example Fixed delay
    #   retry_delay = 30 # 30 seconds interval between each retry
    #
    # @example Dynamic delay
    #   retry_delay = ->(retry_count) {
    #     (1 + retry_count) * 60 # 1min, 2min, 3min...
    #   }
    #
    # @param [Integer, Proc] delay fixed delay in seconds or Proc that returns number of seconds dynamically
    def retry_delay=(delay)
      @retry_delay = delay
    end

    # Define global handler for exhausted retries of a given message
    #
    # @yield [message, retry_count] Use this to notify your team when a message failed to process too many times
    def on_retries_exhausted(&block)
      @retries_exhausted_handler = block
    end

    def queue(queue_name)
      queues[queue_name.to_s]
    end

    def valid_queue?(queue_name)
      queues.key?(queue_name.to_s)
    end
  end
end

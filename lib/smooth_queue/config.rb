require 'logger'

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

    attr_reader :queues, :retries_exhausted_handler

    # @overload logger
    #   Returns the logger
    # @overload logger=
    #   Define logger
    #
    #   Default: +Logger.new(STDOUT)+
    #
    #   @param [Logger] logger a logger instance
    attr_accessor :logger

    # @overload max_retries
    #   Returns maximum retries
    # @overload max_retries=
    #   Define global maximum retries
    #
    #   Default: +25+
    #
    #   @param [Integer] max_retries must be >= 0
    attr_accessor :max_retries

    # @overload retry_delay
    #   Returns retry delay
    # @overload retry_delay=
    #   Define global retry delay
    #
    #   Default:
    #     ->(retry_count) { (retry_count ** 4) + 15 + (rand(30) * (retry_count + 1)) }
    #
    #   @example Dynamic delay. The retry_count starts at 0 and the payload contains the message and other metadata
    #     retry_delay = ->(retry_count, payload) {
    #       (1 + retry_count) * 60 # 1min, 2min, 3min...
    #     }
    #
    #   @param [Proc] Proc that returns number of seconds dynamically
    attr_accessor :retry_delay

    def initialize
      @max_retries = 25
      @queues = {}
      @retries_exhausted_handler = ->() {}
      @logger = Logger.new(STDOUT)
      @retry_delay = ->(retry_count, _payload) { (retry_count**4) + 15 + (rand(30) * (retry_count + 1)) }
    end

    # Add queue definition
    #
    # @param [String] queue_name
    # @param [Integer] max_concurrency number of messages allowed to be processed simultaneously
    # @yield [id, message] called when a message is ready for processing. Make sure this block runs in O(1)
    def add_queue(queue_name, max_concurrency, &handler)
      queues[queue_name.to_s] = Queue.new(queue_name.to_s, max_concurrency, handler)
    end

    # Define global handler for exhausted retries of a given message
    #
    # @yield [payload] Use this to notify your team when a message failed to process too many times.
    # The payload is a hash containing +queue+, +message+, +retry_count+ and perhaps other useful data
    def on_retries_exhausted(&block)
      @retries_exhausted_handler = block
    end

    # Define error handler
    #
    # @yield [exception] Use this to notify your team when an unexpected error occurrs on SmoothQueue loop
    def on_error(&block)
      @error_handler = block
    end
  end
end

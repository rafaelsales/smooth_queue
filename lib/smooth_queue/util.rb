require 'time'
require 'securerandom'

module SmoothQueue
  module Util
    def self.build_message_payload(queue, message)
      {
        'created_at'.freeze => Time.now.utc.iso8601.freeze,
        'message'.freeze => message,
        'queue'.freeze => queue.freeze,
      }
    end

    def self.generate_id
      SecureRandom.hex(12).freeze
    end

    def self.from_json(json)
      return unless json
      json.is_a?(Hash) ? json : JSON.parse(json)
    end

    def self.to_json(hash)
      return unless hash
      JSON.generate(hash)
    end
  end
end

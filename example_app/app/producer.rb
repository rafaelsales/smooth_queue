class Producer
  def self.run
    8.times do |i|
      SmoothQueue.enqueue('heavy_lifting', id: i, foo: 'bar')
      SmoothQueue.enqueue('very_heavy_lifting', id: i, bar: 'baz')
    end

    loop do
      stats = SmoothQueue.stats
      puts "#{Time.now.iso8601} Status: #{stats.to_json}"
      break if stats.values.all? { |queue_stats|
        queue_stats.is_a?(Integer) ? queue_stats.zero? : queue_stats.values.all?(&:zero?)
      }
      sleep 2
    end
  end
end

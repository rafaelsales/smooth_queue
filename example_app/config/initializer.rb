Redis.new.flushall

SmoothQueue.configure do |config|
  config.add_queue('heavy_lifting', 6) do |id, message|
    HeavyLiftingWorker.perform_later(id, message)
  end

  config.add_queue('very_heavy_lifting', 4) do |id, message|
    VeryHeavyLiftingWorker.perform_later(id, message)
  end
end

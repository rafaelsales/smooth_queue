class HeavyLiftingWorker < BackgroundWorker
  def process(id, message)
    sleep 3 + rand(0..2.0)
    SmoothQueue.done(id)
  rescue => e
    SmoothQueue.retry(id)
  end
end

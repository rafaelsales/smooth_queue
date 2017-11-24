class VeryHeavyLiftingWorker < BackgroundWorker
  def process(id, message)
    sleep 5 + rand(0..4.0)
    SmoothQueue.done(id)
  rescue => e
    SmoothQueue.retry(id)
  end
end

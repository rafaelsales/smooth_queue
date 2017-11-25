class VeryHeavyLiftingWorker < BackgroundWorker
  def process(id, _message)
    sleep 5 + rand(0..4.0)
    SmoothQueue.done(id)
  rescue
    SmoothQueue.retry(id)
  end
end

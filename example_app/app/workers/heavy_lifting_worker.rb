class HeavyLiftingWorker < BackgroundWorker
  def process(id, _message)
    sleep 3 + rand(0..2.0)
    SmoothQueue.done(id)
  rescue
    SmoothQueue.retry(id)
  end
end

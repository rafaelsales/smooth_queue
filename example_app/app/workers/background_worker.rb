class BackgroundWorker
  def self.perform_later(*args)
    Thread.new do
      begin
        job_id = SecureRandom.hex(12).freeze
        logger.info "#{name}: Job #{job_id} starting with args #{args.join(', ')}"
        new.process(*args)
        logger.info "#{name}: Job #{job_id} finished"
      rescue => e
        logger.error "Worker failed: #{e.class} - #{e.message}"
      end
    end
  end

  def self.logger
    @logger ||= Logger.new('log/worker.log')
  end

  def logger
    self.class.logger
  end
end

class BaseWorker
  include Sidekiq::Worker

  class << self
    attr_accessor :blocked_by_classes, :looping_interval
  end

  def perform(*payload)
    ActiveRecord::Base.connection_pool.with_connection do
      return if requeued_because_blocked(payload)
      self.process(*payload)
      requeue_if_looping(payload)
    end
    # GC.start if rand <= 0.05
  end

  def process;fail('must implement in worker class');end

  def self.blocked_by(*classes)
    fail('expecting BaseWorker subclasses') if classes.any?{|klass| !klass.ancestors.include?(BaseWorker)}
    self.blocked_by_classes = classes
  end

  def self.runs_every(interval)
    self.looping_interval = interval
  end

  def requeued_because_blocked(payload)
    if self.class.blocked_by_classes.present? && self.class.blocked_by_classes.any?{|klass| klass.exists?}
      self.class.perform_in(15.minutes, *payload) unless self.class.pending?
      return true
    end
    return false
  end

  def requeue_if_looping(payload)
    if self.class.looping_interval.present?
      self.class.perform_in(fuzz_by(value: self.class.looping_interval).round.to_i, *payload) unless self.class.pending?
      return true
    end
    return false
  end

  def self.queued?
    Sidekiq::Queue.all.any? do |queue|
      queue.any? do |job|
        job.klass == self.name
      end
    end
  end

  def self.scheduled?
    Sidekiq::ScheduledSet.new.any? do |job|
      job.klass == self.name
    end
  end

  def self.retry_queued?
    Sidekiq::RetrySet.new.any? do |job|
      job.klass == self.name
    end
  end

  def self.running?
    Sidekiq::Workers.new.any? do |process_id, thread_id, data|
      data&.fetch('payload', {})&.fetch('class', nil) == self.name
    end
  end

  def self.pending?
    return queued? || scheduled? || retry_queued?
  end

  def self.exists?
    return running? || pending?
  end

  private

  def fuzz_by(value:, fuzz: 0.15)
    value - (value * fuzz) + (2 * value * fuzz * rand)
  end

end

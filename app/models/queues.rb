class Queues

  def initialize
    @queues ||= Hash.new
  end

  def all
    @queues
  end

  def add(channel)
    @queues[channel.to_sym] = Queue.new
  end

  def find(channel)
    @queues[channel.to_sym]
  end

  def find_or_add(channel)
    find(channel) || add(channel)
  end
end

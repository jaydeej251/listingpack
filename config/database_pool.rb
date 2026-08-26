# Solid Queue (supervisor + dispatcher + N worker threads) needs more connections
# than Puma's request threads. Prefer DB_POOL; otherwise at least 5 or RAILS_MAX_THREADS.
module DatabasePool
  module_function

  MINIMUM_FOR_SOLID_QUEUE = 5

  def size
    explicit = ENV["DB_POOL"].presence&.to_i
    return explicit if explicit&.positive?

    threads = ENV.fetch("RAILS_MAX_THREADS", "5").to_i
    [ threads, MINIMUM_FOR_SOLID_QUEUE ].max
  end
end

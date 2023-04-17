module RedisHelpers
  def redis
    @redis ||=Redis::Namespace.new(:slock_test, redis: Redis.new)
  end
end

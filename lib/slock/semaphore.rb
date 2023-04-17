module Slock
  class Semaphore
    autoload :Lock, 'slock/semaphore/lock'
    autoload :Health, 'slock/semaphore/health'
    autoload :Singleton, 'slock/semaphore/singleton'

    # @return [Redis]
    attr_reader :client
    # @return [Integer]
    attr_reader :size

    #
    # @param [String, Symbol] key
    # @param [Hash] opts
    # @option opts [Integer] :size
    # @option opts [Integer] :timeout
    # @option opts [Integer] :lifetime
    #
    def initialize(key, opts = {})
      @key = key
      @client = ConnectionPool::Wrapper.new(size: 50) { opts.delete(:redis) || Redis.new }
      @size = opts.delete(:size) || 1
      @opts = opts

      initialize_semaphore
    end

    def initialize_semaphore
      return if client.getset(init_path, '1') == '1'

      client.del(tokens_path) if client.exists?(tokens_path)
      size.times { |n| client.rpush(tokens_path, n) }
    end

    #
    # @param [Hash] opts
    # @option opts [Integer] :timeout
    # @option opts [Integer] :lifetime
    #
    # @return [Slock::Semaphore::Lock] returns lock's handler when no block is provided
    # @return [Object] returns yielded block resulst when block is provided
    #
    def acquire(opts = {}, &block)
      check_health!
      opts = @opts.merge(opts)
      lock = opts[:timeout] ? acquire_timeout(opts) : acquire_notimeout(opts)
      return lock unless block_given?
      yield(lock) if lock.locked?
    ensure
      lock&.release if block_given?
    end

    #
    # @param [Hash] opts
    # @option opts [Integer] :timeout
    # @option opts [Integer] :lifetime
    #
    # @return [Slock::Semaphore::Lock]
    #
    def acquire_timeout(opts = {})
      Timeout::timeout(opts[:timeout]) { acquire_notimeout(opts) }
    rescue Timeout::Error
      raise Errors::TimeoutError
    end

    #
    # @param [Hash] opts
    # @option opts [Integer] :timeout
    # @option opts [Integer] :lifetime
    #
    # @return [Slock::Semaphore::Lock]
    #
    def acquire_notimeout(opts = {})
      Semaphore::Lock.lock(self, opts)
    end

    def check_health!
      Semaphore::Health.new(self).check!
    end

    #
    # @param [Arra<String, Symbol, nil, Integer>] postfixes
    #
    def key(*postfixes)
      [@key, *postfixes].compact.join(':')
    end

    #
    # @return [String]
    #
    def tokens_path
      key(:tokens)
    end

    #
    # @return [String]
    #
    def init_path
      key(:init)
    end
  end
end

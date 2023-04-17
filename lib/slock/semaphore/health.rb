module Slock
  class Semaphore
    class Health
      extend Forwardable

      # @return [Integer]
      HEALTHCHECK_TIMEOUT = 10

      def_delegators :semaphore, :key, :size, :tokens_path, :client

      # @return [Slock::Semaphore]
      attr_reader :semaphore


      #
      # @param [Slock::Semaphore] semaphore
      #
      def initialize(semaphore)
        @semaphore = semaphore
      end

      def check!
        check if lock
      end

      def check
        client.watch(tokens_path) do
          missing_tokens.shuffle.each do |token|
            lock = Semaphore::Lock.new(self, token)
            lock.fix! unless lock.live?
          end
        end
      ensure
        client.del(healthlock_path)
        client.unwatch
      end

      #
      # @return [Array<String>]
      #
      def missing_tokens
        size.times.map(&:to_s) - client.lrange(tokens_path, 0, -1)
      end

      #
      # @return [Boolean]
      #
      def lock
        !!client.set(healthlock_path, 1, nx: true, ex: HEALTHCHECK_TIMEOUT)
      end

      #
      # @return [String]
      #
      def healthlock_path
        key(:healthlock)
      end
    end
  end
end

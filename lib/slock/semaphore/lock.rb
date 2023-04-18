module Slock
  class Semaphore
    class Lock
      extend Forwardable

      attr_reader :id
      attr_reader :semaphore, :token, :lifetime

      def_delegators :semaphore, :key, :client, :tokens_path

      #
      # @param [Slock::Semaphore] semaphore
      # @param [String] token
      # @param [Hash] opts
      # @option opts [Integer] :timeout
      # @option opts [Integer] :lifetime
      #
      def initialize(semaphore, token, opts = {})
        @semaphore = semaphore
        @token = token
        @id = SecureRandom.uuid
        @lifetime = opts.delete(:lifetime) || (10 * 60)
      end

      #
      # @return [Boolean]
      #
      def locked?
        client.get(id_path) == id
      end

      def self.lock(semaphore, opts = {})
        _, token = semaphore.client.blpop(semaphore.tokens_path, timeout: 0)
        raise Errors::TokenOutOffSemaphoreSizeError if token.to_i >= semaphore.size

        new(semaphore, token, opts).tap(&:lock)
      rescue Redis::TimeoutError, Errors::WrongLockOwnerError,
             Errors::TokenOutOffSemaphoreSizeError

        retry
      end

      def lock
        change do
          check_owner!(true)
          renew
          own
        end
      end

      def release
        change { owned? ? _release : false }
      end

      def _release
        client.del(id_path)
        client.del(live_path)
        client.rpush(tokens_path, token)
      end

      def renew
        client.set(live_path, id, ex: lifetime)
      end

      def own
        client.set(id_path, id)
      end

      #
      # @param [String] allow_empty
      #
      # @return [Boolean]
      #
      def owned?(allow_empty = false)
        owner = client.get(id_path)
        return true if owner.nil? && allow_empty

        owner == id
      end

      #
      # @param [Boolean] allow_empty
      #
      # @raise [Semaphore::Errors::WrongLockOwnerError]
      #
      def check_owner!(allow_empty = false)
        return if owned?(allow_empty)

        raise Errors::WrongLockOwnerError, token
      end

      #
      # @return [Boolean]
      #
      def live?
        client.exists?(live_path)
      end

      def fix!
        change do
          client.multi do |tx|
            tx.del(id_path)
            tx.del(live_path)
            tx.lpush(tokens_path, token)
          end
        end
      end

      def change
        return yield if @changable

        begin
          sleep(0.1) until client.set(lock_path, 1, nx: true, ex: 3)
          @changable = true

          yield
        ensure
          @changable = false
          client.del(lock_path)
        end
      end

      #
      # @return [String]
      #
      def lock_path
        key(:tokens, token, :lock)
      end

      #
      # @return [String]
      #
      def id_path
        key(:tokens, token, :id)
      end

      #
      # @return [String]
      #
      def live_path
        key(:tokens, token, :live)
      end
    end
  end
end

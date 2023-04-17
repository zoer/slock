module Slock
  class Semaphore
    module Singleton
      module ClassMethods
        def acquire(*args, &block)
          instance.semaphore.acquire(*args, &block)
        end
      end

      def self.included(base)
        base.include ::Singleton
        base.extend ClassMethods
      end

      #
      # @return [Slock::Semaphore]
      #
      def semaphore
        @semaphore ||= begin
          opts = semaphore_opts.dup
          key = opts.delete(:key) || "semaphore:#{self.class.name.underscore}"
          Slock::Semaphore.new(key, opts)
        end
      end

      #
      # @return [Hash{Symbol => Object}]
      #
      def semaphore_opts
        raise NotImplementedError
      end
    end
  end
end

module Slock
  module Errors
    class BaseError < StandardError; end
    class TimeoutError < BaseError; end
    class WrongLockOwnerError < BaseError; end
    class TokenOutOffSemaphoreSizeError < BaseError; end
  end
end

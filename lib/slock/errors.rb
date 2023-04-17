module Slock
  module Errors
    class TimeoutError < StandardError; end
    class WrongLockOwnerError < StandardError; end
  end
end

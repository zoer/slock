require 'securerandom'
require 'forwardable'

module Slock
  autoload :Semaphore, 'slock/semaphore'
  autoload :Errors, 'slock/errors'
end

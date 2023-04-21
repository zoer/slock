# Slock
[![Code Climate](https://codeclimate.com/github/zoer/slock/badges/gpa.svg)](https://codeclimate.com/github/zoer/slock)
[![Inline docs](http://inch-ci.org/github/zoer/slock.png)](http://inch-ci.org/github/zoer/slock)
[![Gem Version](https://badge.fury.io/rb/slock.svg)](http://badge.fury.io/rb/slock)

Slock implements Semaphore via Redis.

## Installation

Add this line to your application's Gemfile:

```ruby
gem 'slock'
```

## Usage

### Singleton Class
```ruby
class MySemaphore
  include Slock::Semaphore::Singleton

  SIZE     = 2   # max count of simultaneous locks
  LIFETIME = 600 # max time that lock lives after acquring (in seconds)
  TIMEOUT  = 900 # max time that semaphore waits for lock to acquire before raising an error

  def semaphore_opts
    {
      redis:    Redis.new(url: ENV['REDIS_URL']),
      size:     SIZE,
      lifetime: LIFETIME,
      timeout:  TIMEOUT
    }
  end
end

MySemaphore.acquire { do_something }
```


### Simple
```ruby
sempahore = Slock::Semaphore.new 'uniq_semaphore_key',
  redis: Redis.new(ENV['REDIS_URL']),
  lifetime: 600,
  timeout: 900

semaphore.acquire { do_something }
```

# Copyright (C) 2009 Mark Somerville <mark@scottishclimbs.com>
# Released under the General Public License (GPL) version 3.
# See COPYING

module Honcho
  # A mutex and condition variable abstraction that is used by the main event
  # loop when waiting for a response.
  class ResponseWaiter
    def initialize
      @mutex = Mutex.new
      @condition_variable = ConditionVariable.new
      @waiting = false
    end

    # Blocks until a response is received, which is then returned.
    def wait
      @mutex.synchronize do
        @waiting = true
        @condition_variable.wait @mutex
        @waiting = false
      end
      return @response
    end

    # Signals that a response is available.
    def signal(response)
      # In some cases, this method can be called before the event loop has
      # called ResponseWaiter#wait. It shouldn't take long though!
      while not @waiting
        sleep 0.001
      end
      @mutex.synchronize do
        @response = response
        @condition_variable.signal
      end
    end
  end
end

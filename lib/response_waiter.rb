module Honcho
  # A mutex and condition variable abstraction that is used by the main event
  # loop when waiting for a response.
  class ResponseWaiter
    # The body of the response
    attr_reader :response

    def initialize
      @mutex = Mutex.new
      @condition_variable = ConditionVariable.new
    end

    # Blocks, waiting for a response.
    def wait
      @mutex.synchronize do
        @response = nil
        @condition_variable.wait @mutex
      end
    end

    # Signals that a rseponse is available.
    def signal(response)
      @mutex.synchronize do
        @response = response
        @condition_variable.signal
      end
    end
  end
end

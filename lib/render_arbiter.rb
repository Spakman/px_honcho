require "thread"

module Honcho
  class RenderArbiter
    attr_reader :queue

    def initialize(fifo_path, render_queue)
      @render_queue = render_queue
      @pipe = File.open fifo_path, "a+"
    end

    # Loops in a thread, sending render requests to Rembrandt as soon as
    # they are available.
    def send_render_requests
      Thread.new do
        loop do
          request = @render_queue.pop
          @pipe << "<render #{request.length}>\n"
          @pipe << request
          @pipe.flush
        end
      end
    end
  end
end

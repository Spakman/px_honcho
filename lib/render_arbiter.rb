require "thread"

module Honcho
  class RenderArbiter
    def initialize(fifo_path, render_queue)
      @render_queue = render_queue
      @pipe = File.open fifo_path, "a+"
    end

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

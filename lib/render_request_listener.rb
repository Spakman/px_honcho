require "thread"

module Honcho
  class RenderRequestListener
    def initialize(socket, queue, focus_manager)
      @socket = socket
      @focus_manager = focus_manager
      @application = File.basename(socket.path, ".socket")
      @queue = queue
    end

    # Listens for requests on the socket and adds them to the render queue if
    # the application currectly has focus. Invalid lines are ignored. A request
    # consists of a message header and the markup to render. The message header
    # is of the form (terminated by a newline character):
    #
    # <request X>
    #
    # where X is the number of bytes in the request that follows.
    def listen_and_queue_requests
      loop do
        header = @socket.gets
        if header =~ /^<render (\d{1,4})>\n$/
          request = @socket.read $1.to_i
          if @focus_manager.has_focus? @application
            @queue << request
          end
        end
      end
    end
  end
end

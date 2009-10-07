require "thread"
require "#{File.dirname(__FILE__)}/response_waiter"

Thread.abort_on_exception = true
module Honcho
  # Listens for incoming messages from a single running application. Multiple 
  # listeners can be run in multiple threads.
  class MessageListener
    def initialize(socket, render_arbiter, response_waiter, focus_manager)
      @socket = socket
      @focus_manager = focus_manager
      @application = File.basename(socket.path, ".socket")
      @render_queue = render_arbiter.queue
      @response_waiter = response_waiter
    end

    # Listens for messages on the socket, ignoring invalid lines. 
    #
    # Render requests are added to the render queue if the application
    # currectly has focus. Responses to event messages cause the 
    # ResponseWaiter to be signalled.
    #
    # A request consists of a message header and the
    # markup to render. The message header is of the form (terminated by a
    # newline character):
    #
    # <render X>
    # <keepfocus X>
    #
    # where X is the number of bytes in the body that follows.
    def listen_and_process_messages
      Thread.new do
        loop do
          begin
            header = @socket.gets
          rescue Errno::ECONNRESET, Errno::EBADF, IOError
            break
          end
          if header =~ /^<(render|keepfocus) (\d{1,4})>\n$/
            if $1 == "render"
              body = @socket.read $2.to_i
              if @focus_manager.has_focus? @application
                @render_queue << body
              end
            else
              @response_waiter.signal "#{header}#{body}"
            end
          end
        end
        cleanup
      end
    end

    # This listener is shutting down and should tidy up before it leaves.
    def cleanup
      @socket.close unless @socket.closed?
      @focus_manager.closed @application
    end
  end
end


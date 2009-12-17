# Copyright (C) 2009 Mark Somerville <mark@scottishclimbs.com>
# Released under the General Public License (GPL) version 3.
# See COPYING

require "thread"
require_relative "response_waiter"
require_relative "message"

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
    def listen_and_process_messages
      Thread.new do
        loop do
          begin
            header = @socket.gets
          rescue Errno::ECONNRESET, Errno::EBADF, IOError => exception
            break
          end
          if header =~ /^<(?<type>\w+) (?<length>\d+)>\n$/
            body = @socket.read $~[:length].to_i
            message = Message.new $~[:type], body
            if message.type == :render
              # Sometimes erroneous applications may send render requests when
              # they are not active.
              if @focus_manager.has_focus? @application
                @render_queue << message.body
              end
            else
              # This is a response, let the waiter know.
              @response_waiter.signal message
            end
          end
        end
        cleanup
      end
    end

    # This listener is shutting down and should tidy up before it leaves.
    def cleanup
      @socket.close unless @socket.closed?
      5.times do
        if @response_waiter.waiting
          @response_waiter.signal Honcho::Message.new(:closing) 
          break
        end
        sleep 0.2
      end
    end
  end
end


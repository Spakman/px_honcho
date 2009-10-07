require "socket"
require "fileutils"
require "#{File.dirname(__FILE__)}/response_waiter"
require "#{File.dirname(__FILE__)}/message_listener"

module Honcho
  # Handles event passing, application loading and focus.
  class ApplicationManager
    APPLICATION_BASE = "#{File.dirname(__FILE__)}/../bin"
    SOCKET_BASE = "/tmp"

    def initialize(render_arbiter, event_listener)
      @render_arbiter = render_arbiter
      @event_listener = event_listener
      @response_waiter = Honcho::ResponseWaiter.new

      @applications = {}
      @current_application = nil
      @pid = nil
    end

    def current_application
      @applications[@current_application]
    end

    # Reads from the event queue and passes them onto the currently active application.
    def event_loop
      loop do
        event = @event_listener.queue.pop
        current_application[:socket] << event.to_message
        response = @response_waiter.wait
      end
    end

    def has_focus?(application)
      application == current_application[:name]
    end

    def load_application(application)
      unless @applications[application]
        FileUtils.rm_f "#{SOCKET_BASE}/#{application}.socket"
        socket = UNIXServer.open "#{SOCKET_BASE}/#{application}.socket"
        socket.listen 1

        pid = fork do
          exec File.expand_path "#{APPLICATION_BASE}/#{application}"
        end

        application_socket = socket.accept

        message_listener = Honcho::MessageListener.new application_socket, @render_arbiter, @response_waiter, self
        Thread.new do
          sleep 0.1
          message_listener.listen_and_process_messages
        end
        @applications[application] = { name: application, socket: application_socket, message_listener: message_listener, pid: pid }
      end
      @current_application = application
    end

    # Sends the TERM signal to all child applications.
    def shutdown
      @applications.each_pair do |name, values|
        Process.kill "TERM", values[:pid]
      end
    end
  end
end

require "socket"
require "fileutils"
require "#{File.dirname(__FILE__)}/response_waiter"
require "#{File.dirname(__FILE__)}/message_listener"

module Honcho
  # An array with some syntactic sugar. This is used to manage the running
  # applications on the system.
  class ApplicationStack < Array
    def active
      last
    end
    
    def active=(name)
      index = find_index { |app| app[:name] == name }
      push delete_at index
    end

    def close_active
      pop
    end

    def running?(name)
      find { |app| app[:name] == name }
    end
  end

  # Handles event passing, application loading and focus.
  class ApplicationManager
    APPLICATION_BASE = "#{File.dirname(__FILE__)}/../bin"
    SOCKET_BASE = "/tmp"

    def initialize(render_arbiter, event_listener)
      @render_arbiter = render_arbiter
      @event_listener = event_listener
      @response_waiter = Honcho::ResponseWaiter.new

      @applications = ApplicationStack.new
      @pid = nil
    end

    # Reads from the event queue and passes them onto the currently active
    # application.
    def event_loop
      loop do
        event = @event_listener.queue.pop
        @applications.active[:socket] << event.to_message
        response = @response_waiter.wait
      end
    end

    def has_focus?(application)
      application == @applications.active[:name]
    end

    def load_application(application)
      unless @applications.running? application
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
        @applications << { name: application, socket: application_socket, message_listener: message_listener, pid: pid }
      end
      @applications.active = application
    end

    # Sends the TERM signal to all child applications.
    def shutdown
      @applications.each do |application_properties|
        Process.kill "TERM", application_properties[:pid]
      end
    end

    # The passed application has closed (or is closing) so we should clean up
    # and switch focus.
    def closed(application)
    end
  end
end

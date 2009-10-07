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

    def index_of(name)
      find_index { |app| app[:name] == name }
    end
    
    def active=(name)
      push delete_at index_of(name)
    end

    def closed(name)
      delete_at index_of(name)
    end

    def running?(name)
      self[index_of(name)] rescue nil
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

    # Sets up a socket, runs the application using fork/exec and then sets up a
    # message listener.
    def load_application(application)
      unless @applications.running? application
        listening_socket = listening_socket_for(application)

        pid = fork { exec executable_path_for(application) }

        socket = listening_socket.accept

        message_listener = Honcho::MessageListener.new socket, @render_arbiter, @response_waiter, self
        message_listener.listen_and_process_messages

        @applications << { name: application, socket: socket, message_listener: message_listener, pid: pid }
      end
      @applications.active = application
    end
    
    # Sets up a socket and starts listening for a connection from the application.
    def listening_socket_for(application)
      FileUtils.rm_f "#{SOCKET_BASE}/#{application}.socket"
      socket = UNIXServer.open "#{SOCKET_BASE}/#{application}.socket"
      socket.listen 1
      socket
    end 

    # Returns the full path to the executable.
    def executable_path_for(application)
      File.expand_path "#{APPLICATION_BASE}/#{application}"
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
      @applications.closed application
    end
  end
end

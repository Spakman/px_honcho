require "socket"
require "fileutils"
require "#{File.dirname(__FILE__)}/response_waiter"
require "#{File.dirname(__FILE__)}/message_listener"
require "#{File.dirname(__FILE__)}/application_stack"

module Honcho
  # Handles event passing, application loading and focus.
  class ApplicationManager
    APPLICATION_BASE = "#{File.dirname(__FILE__)}/../apps"
    SOCKET_BASE = "/tmp"

    def initialize(render_arbiter, event_listener)
      @render_arbiter = render_arbiter
      @event_listener = event_listener
      @response_waiter = Honcho::ResponseWaiter.new

      @applications = ApplicationStack.new
      @pid = nil
      at_exit { shutdown }
    end

    # Reads from the event queue and passes them onto the currently active
    # application.
    def event_loop
      loop do
        event = @event_listener.queue.pop
        @applications.active[:socket] << event.to_message
        act_on_response @response_waiter.wait
      end
    end

    def act_on_response(response)
      case response.type
      when :passfocus
        load_application response.body["application"]
        @applications.active[:socket] << Message.new(:havefocus)
        act_on_response @response_waiter.wait
      when :closing
        @applications.close_active
        @applications.active[:socket] << Message.new(:havefocus)
        @response_waiter.wait
      when :keepfocus
      else
      end
    end

    def has_focus?(application)
      application == @applications.active[:name] rescue nil
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
      @applications.each do |application|
        @applications.close application[:name]
      end
    end
  end
end

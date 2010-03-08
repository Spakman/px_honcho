# Copyright (C) 2009 Mark Somerville <mark@scottishclimbs.com>
# Released under the General Public License (GPL) version 3.
# See COPYING

require "socket"
require "fileutils"
require_relative "response_waiter"
require_relative "message_listener"
require_relative "application_stack"
require_relative "backlight_controller"

module Honcho
  # Handles event passing, application loading and focus.
  class ApplicationManager
    APPLICATION_BASE = "#{ENV['PROJECT_X_BASE']}/apps"
    SOCKET_BASE = "/tmp"

    def initialize(render_arbiter, event_listener)
      @render_arbiter = render_arbiter
      @event_listener = event_listener
      @response_waiter = Honcho::ResponseWaiter.new

      @applications = ApplicationStack.new
      at_exit { shutdown }
      @backlight = BacklightController.new("/tmp/backlight", 5)
    end

    # Reads from the event queue and passes them onto the currently active
    # application.
    def event_loop
      loop do
        event = @event_listener.queue.pop
        @backlight.on!
        send_message event.to_message
      end
    end

    # Sends the passed message to the active application.
    def send_message(message)
      @applications.active[:socket] << message
      response = @response_waiter.wait
      act_on_response(response)
    end

    # Handles the message response from the active application.
    def act_on_response(response)
      case response.type
      when :passfocus
        if response.body
          application = response.body.delete :application
          load_application application
        else
          @applications.move_active_to_bottom
        end
        send_message Message.new(:havefocus, response.body)
      when :closing
        @applications.close_active
        send_message Message.new(:havefocus)
      when :keepfocus
      else
      end
    end

    def has_focus?(application)
      application == @applications.active[:name] rescue nil
    end

    # Sets up a socket, runs the application using fork/exec and then sets up a
    # message listener for the application.
    def load_application(application, options = { has_focus: true })
      if @applications.running? application
        @applications.active = application
      else
        listening_socket = listening_socket_for(application)

        pid = fork do
          exec executable_path_for(application)
        end

        socket = listening_socket.accept
        socket.close_on_exec = true

        message_listener = Honcho::MessageListener.new socket, @render_arbiter, @response_waiter, self
        message_listener.listen_and_process_messages

        application_hash = { name: application, socket: socket, message_listener: message_listener, pid: pid }

        if options[:has_focus]
          @applications << application_hash
          send_message Message.new(:havefocus)
        else
          @applications.unshift application_hash
        end
      end
    end
    
    # Sets up a socket and starts listening for a connection from the application.
    def listening_socket_for(application)
      FileUtils.rm_f "#{SOCKET_BASE}/#{application}.socket"
      socket = UNIXServer.open "#{SOCKET_BASE}/#{application}.socket"
      socket.close_on_exec = true
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

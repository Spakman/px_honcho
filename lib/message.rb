# Copyright (C) 2009 Mark Somerville <mark@scottishclimbs.com>
# Released under the General Public License (GPL) version 3.
# See COPYING

require "yaml"

module Honcho
  # = Messages
  #
  # Defines a message that Honcho sends or receives from the applications.
  #
  # Messages are fundamental to nearly all applications on the device and
  # consist of requests, responses and render requests. Requests are sent by
  # Honcho to alert an application to some event, like a button press or a
  # change in focus. When Honcho sends a request to the currently running
  # application, it hangs waiting for a response so it is *essential* that a
  # response is sent back in return. Request responses are a little different
  # since they can be sent from an application at any time (it can be outwith
  # the request/response cycle).
  #
  # A message consists of a message header, which contains the message type
  # and the length of the body of the message (which can be zero) and is
  # terminated by a newline charater. The body follows, the format of which
  # varies with the type.
  #
  # == Requests
  #
  # === havefocus
  #
  # Alerts an application that is now has focus. If no body is passed, the
  # default behaviour of the application takes place. If the body is popoulated
  # with a method and params, the application should take whatever action is
  # defined:
  #
  #   <havefocus 0>\n
  #
  #   <havefocus 30>\n
  #   method: play_ids
  #   params: 1,2,3
  #
  # === inputevent
  #
  # Lets an application know that a button has been pressed. The body always
  # contains the button identifier, one of 'top_left', 'top_right',
  # 'bottom_left', 'bottom_right', 'jog_wheel_left', 'jog_wheel_right' or
  # 'jog_wheel_button':
  #
  #   <inputevent 8>\n
  #   top_left
  #
  # === render
  #
  # Contains some markup to be rendered to the screen:
  #
  #   <render 36>\n
  #   <title>Some markup to render</title>
  #
  # == Responses
  #
  # === keepfocus
  #
  # This response let's Honcho know the application wishes to retain focus:
  #
  #   <keepfocus 0>\n
  #
  # === passfocus
  #
  # This response let's Honcho know the application wishes to pass focus to
  # another application. If no body is passed, Honcho moves the response
  # sending application to the bottom of the ApplicationStack and gives focus
  # to the previously focused application. If a body and parameters are
  # included, focus is passed to a specified application and (potentially), a
  # remote method is called on that application.
  #
  #   <passfocus 0>\n
  #
  #   <passfocus 50>\n
  #   application: mozart
  #   method: play_ids
  #   params: 1,2,3
  #
  # === closing
  #
  # This response let's Honcho know the application is closing. Focus is passed
  # to the previously focused application:
  #
  #   <closing 0>\n
  #
  # == Render request
  #
  # Contains some markup to be rendered to the screen:
  #
  #   <render 36>\n
  #   <title>Some markup to render</title>
  class Message
    attr_reader :type, :body

    def initialize(type, body = nil)
      @type = type.to_sym
      @body = case @type
      when :passfocus
        if body.respond_to? :bytes
          # symbolise the keys
          body.gsub!(/^(\w+:)/, ':\1')
          YAML::load body rescue nil
        else
          body
        end
      else
        body
      end
    end

    def to_s
      if @body.kind_of? Hash
        body = ""
        @body.each_pair { |key,value| body << "#{key}: #{value}\n" }
        body.chomp!
      else
        body = @body
      end
      "<#{type} #{body.to_s.length}>\n#{body}"
    end

    alias_method :to_str, :to_s
  end
end

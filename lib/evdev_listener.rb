# Copyright (C) 2009 Mark Somerville <mark@scottishclimbs.com>
# Released under the General Public License (GPL) version 3.
# See COPYING

require "evdev"
require "thread"
require_relative "message"

module Honcho
  class InputEvent
    attr_reader :button

    def initialize(button)
      @button = button
    end

    # Returns the Honcho message for this event.
    def to_message
      Message.new :inputevent, @button
    end
  end

  class EvdevListener
    attr_reader :queue

    def initialize
      @queue = Queue.new
    end

    def listen_and_process_events(keyboards)
      keyboards.each do |keyboard| 
        Thread.new do
          device = Evdev::EventDevice.new keyboard
          loop do
            begin
              event = device.read_event
              filter_and_queue event
            rescue Errno::ENODEV
              break
            end
          end
          device.close rescue Errno::ENODEV
        end
      end
    end

    def keyboards
      devices = []
      Dir.glob('/dev/input/event*').sort.each do |file|
        next if not File.readable? file
        Evdev::EventDevice.open(file) do |device|
          begin
            device.feature_type_named('KEY')
            device.feature_type_named('REP')
            devices << device.path
          rescue
          end
        end
      end
      devices
    end

    # Adds the event to the queue if the event is a key release. All other
    # events are ignored.
    def filter_and_queue(evdev_event)
      if evdev_event.feature.type.name == 'KEY' and evdev_event.value == 0 
        event = case evdev_event.feature.code
        when 71
          InputEvent.new :top_left
        when 73
          InputEvent.new :top_right
        when 79
          InputEvent.new :bottom_left
        when 81
          InputEvent.new :bottom_right
        when 75
          InputEvent.new :jog_wheel_left
        when 76
          InputEvent.new :jog_wheel_button
        when 77
          InputEvent.new :jog_wheel_right
        else
          nil
        end
        @queue << event unless event.nil?
      end
    end
  end
end

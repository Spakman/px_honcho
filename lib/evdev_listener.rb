require "evdev"
require "thread"

class EvdevListener
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
  def filter_and_queue(event)
    if event.feature.type.name == 'KEY' and event.value == 0 
      @queue << event
    end
  end
end

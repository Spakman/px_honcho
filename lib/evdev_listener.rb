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
          rescue Errno::ENODEV
            break
          end
          @queue << event.feature.code
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
end

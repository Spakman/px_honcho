module Honcho
  # A simple class that writes a 1 or a 0 to a file in order to indicate the desired state of an LCD backlight. The light remains on for some seconds after the call to #on!.
  class BacklightController
    def initialize(filepath, stays_on_for = 5)
      @filepath = filepath
      @on = false
      start_turn_off_thread(stays_on_for)
    end

    def on?
      @on
    end

    def off?
      !@on
    end

    # Turns the backlight on. The backlight will be turned off after the number
    # of seconds specified when the class was initialized.
    def on!
      unless on?
        write_to_file "1"
      end
      @backlight_last_on = Time.now
      @on = true
    end

    # Turns the backlight off.
    def off!
      if on?
        write_to_file "0"
        @on = false
      end
    end

    def write_to_file(contents)
      File.open(@filepath, "w") do |file|
        file << contents
      end
    end

    # Runs a thread that simply loops and turns the backlight off when a
    # certain time has passed since it was last turned on. This isn't all that
    # accurate (from a consistency point of view), but it lightweight.
    def start_turn_off_thread(stays_on_for)
      Thread.new do
        loop do
          sleep stays_on_for
          if on? and Time.now - stays_on_for > @backlight_last_on
            off!
          end
        end
      end
    end
  end
end

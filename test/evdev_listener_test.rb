require 'test/unit'
require 'fileutils'
require 'inline'
require "#{File.dirname(__FILE__)}/../lib/evdev_listener"

class Honcho::EvdevListener
  attr_accessor :queue
end

class EvdevListenerTest < Test::Unit::TestCase

  KEY_KP4 = 75

  inline do |builder|
    builder.include '"stdio.h"'
    builder.include '"unistd.h"'
    builder.include '"fcntl.h"'
    builder.include '"linux/uinput.h"'
    builder.c '
      int add_keyboard() {
        int uinput_fd = -1;
        struct uinput_user_dev device;
        uinput_fd = open("/dev/input/uinput", O_WRONLY | O_NDELAY);
        if (uinput_fd == -1) {
                printf("Unable to open /dev/input/uinput\n");
                return -1;
        }
        memset(&device, 0, sizeof(device)); // Intialize the uInput device to NULL
        strncpy(device.name, "Project-X hardware buttons", UINPUT_MAX_NAME_SIZE);
        device.id.version = 4;
        device.id.bustype = BUS_USB;

        // Setup the uinput device
        ioctl(uinput_fd, UI_SET_EVBIT, EV_KEY);
        ioctl(uinput_fd, UI_SET_EVBIT, EV_REP);

        ioctl(uinput_fd, UI_SET_KEYBIT, KEY_KP4);
        ioctl(uinput_fd, UI_SET_KEYBIT, KEY_KP6);
        ioctl(uinput_fd, UI_SET_KEYBIT, KEY_KP5);
        ioctl(uinput_fd, UI_SET_KEYBIT, KEY_KP7);
        ioctl(uinput_fd, UI_SET_KEYBIT, KEY_KP9);
        ioctl(uinput_fd, UI_SET_KEYBIT, KEY_KP1);
        ioctl(uinput_fd, UI_SET_KEYBIT, KEY_KP3);

        write(uinput_fd, &device, sizeof(device));
        if (ioctl(uinput_fd, UI_DEV_CREATE)) {
                printf("Unable to create UINPUT device.\n");
                return -1;
        }
        sleep(1);
        return uinput_fd;
      }'
  end

  inline do |builder|
    builder.include '"unistd.h"'
    builder.include '"linux/uinput.h"'
    builder.c '
      void send_key_event(int uinput_fd, int keycode) {
        struct input_event key_event, syn_event;

        gettimeofday(&key_event.time, NULL);
        key_event.type = EV_KEY;
        key_event.code = keycode;
        key_event.value = 1;
        write(uinput_fd, &key_event, sizeof(key_event));

        gettimeofday(&syn_event.time, NULL);
        syn_event.type = EV_SYN;
        syn_event.code = SYN_REPORT;
        syn_event.value = 0;
        write(uinput_fd, &syn_event, sizeof(syn_event));

        gettimeofday(&key_event.time, NULL);
        key_event.value = 0;
        write(uinput_fd, &key_event, sizeof(key_event));

        gettimeofday(&syn_event.time, NULL);
        write(uinput_fd, &syn_event, sizeof(syn_event));
      }'
  end

  inline do |builder|
    builder.include '"unistd.h"'
    builder.include '"linux/uinput.h"'
    builder.c '
      void destroy_keyboard(int uinput_fd) {
        ioctl(uinput_fd, UI_DEV_DESTROY);
        close(uinput_fd);
      }'
  end

  Thread.abort_on_exception = true

  def setup
    @listener = Honcho::EvdevListener.new
    @keyboard_fd = add_keyboard
  end

  def teardown
    destroy_keyboard(@keyboard_fd)
  end

  def test_find_keyboards
    destroy_keyboard(@keyboard_fd)
    num_keyboards = @listener.keyboards.length
    @keyboard_fd = add_keyboard
    assert_equal num_keyboards+1, @listener.keyboards.length
  end

  def test_read_event
    @listener.listen_and_process_events [ @listener.keyboards.last ]
    sleep 0.2
    send_key_event(@keyboard_fd, KEY_KP4)
    sleep 0.2
    assert_equal 1, @listener.queue.size
    event = @listener.queue.pop
    assert_equal Honcho::InputEvent, event.class
    assert_equal :jog_wheel_left, event.button
  end

  def test_input_event_to_message
    event = Honcho::InputEvent.new :top_left
    assert_kind_of Honcho::Message, event.to_message
    assert_equal "<inputevent 8>\ntop_left", event.to_message.to_s
  end
end

require "test/unit"
require "socket"
require "fileutils"
require "thread"
require "#{File.dirname(__FILE__)}/../lib/message_listener"

class HasFocusFocusManager
  def has_focus?(application)
    true
  end
end

class DoesNotHaveFocusFocusManager
  def has_focus?(application)
    false
  end
end

class Honcho::MessageListener
  attr_reader :application
end

class MessageListenerTest < Test::Unit::TestCase
  def setup
    @socket_path = "/tmp/message_listener_test.socket"
    FileUtils.rm_f @socket_path
    listening_socket = UNIXServer.open @socket_path
    listening_socket.listen 1
    @writing_socket = UNIXSocket.open @socket_path
    @reading_socket = listening_socket.accept
    @queue = Queue.new
  end

  def teardown
    @writing_socket.close
    @reading_socket.close
    FileUtils.rm_f @socket_path
  end

  # The sleep give listeners time to start listening and add requests to the queue
  def write_request_to_socket(request)
    sleep 0.1
    @writing_socket << "<render #{request.length}>\n#{request}"
    sleep 0.1
  end

  def test_set_application_name
    focus_manager = HasFocusFocusManager.new
    listener = Honcho::MessageListener.new @reading_socket, @queue, focus_manager
    assert_equal "message_listener_test", listener.application
  end

  def test_queue_requests_for_active_application
    focus_manager = HasFocusFocusManager.new
    Thread.new do
      listener = Honcho::MessageListener.new @reading_socket, @queue, focus_manager
      begin
        listener.listen_and_queue_requests
      rescue IOError
      end
    end
    write_request_to_socket "12345678901234"
    assert_equal 1, @queue.size
    write_request_to_socket "1234"
    assert_equal 2, @queue.size
    assert_equal "12345678901234", @queue.pop
  end

  def test_ignore_request_for_inactive_application
    focus_manager = DoesNotHaveFocusFocusManager.new
    Thread.new do
      listener = Honcho::MessageListener.new @reading_socket, @queue, focus_manager
      begin
        listener.listen_and_queue_requests
      rescue IOError
      end
    end
    write_request_to_socket "12345678901234"
    write_request_to_socket "12345678901234"
    assert_equal 0, @queue.size
  end
end

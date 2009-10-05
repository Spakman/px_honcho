require "test/unit"
require "socket"
require "fileutils"
require "thread"
require "#{File.dirname(__FILE__)}/../lib/message_listener"

Thread.abort_on_exception = true
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
    @render_queue = Queue.new
    @response_waiter = Honcho::ResponseWaiter.new
  end

  def teardown
    @writing_socket.close
    @reading_socket.close
    FileUtils.rm_f @socket_path
  end

  # The sleep give listeners time to start listening and add requests to the queue
  def write_render_request_to_socket(request)
    sleep 0.1
    @writing_socket << "<render #{request.length}>\n#{request}"
    sleep 0.1
  end

  # The sleep give listeners time to start listening and add requests to the queue
  def write_keep_focus_response
    Thread.new do
      sleep 1
      @writing_socket << "<keepfocus 0>\n"
      sleep 0.1
    end
  end

  def test_set_application_name
    focus_manager = HasFocusFocusManager.new
    listener = Honcho::MessageListener.new @reading_socket, @render_queue, @response_waiter, focus_manager
    assert_equal "message_listener_test", listener.application
  end

  def test_queue_render_requests_for_active_application
    focus_manager = HasFocusFocusManager.new
    Thread.new do
      listener = Honcho::MessageListener.new @reading_socket, @render_queue, @response_waiter, focus_manager
      listener.listen_and_process_messages rescue IOError
    end
    write_render_request_to_socket "12345678901234"
    assert_equal 1, @render_queue.size
    write_render_request_to_socket "1234"
    assert_equal 2, @render_queue.size
    assert_equal "12345678901234", @render_queue.pop
  end

  def test_ignore_render_request_for_inactive_application
    focus_manager = DoesNotHaveFocusFocusManager.new
    Thread.new do
      listener = Honcho::MessageListener.new @reading_socket, @render_queue, @response_waiter, focus_manager
      listener.listen_and_process_messages rescue IOError
    end
    write_render_request_to_socket "12345678901234"
    write_render_request_to_socket "12345678901234"
    assert_equal 0, @render_queue.size
  end

  def test_resume_event_loop_on_keep_focus_response
    focus_manager = HasFocusFocusManager.new
    Thread.new do
      listener = Honcho::MessageListener.new @reading_socket, @render_queue, @response_waiter, focus_manager
      listener.listen_and_process_messages rescue IOError
    end
    write_keep_focus_response
    @response_waiter.wait
    assert_nil @response_waiter.response
  end
end

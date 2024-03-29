require "test/unit"
require "socket"
require "fileutils"
require "thread"
require_relative "../lib/message_listener"

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
  attr_reader :application, :socket
end

class ExceptionSocket
  attr_reader :gets_count
  def initialize(exception)
    @exception = exception
    @gets_count = 0
    @closed = false
  end

  def path
    "/dev/null"
  end

  def gets
    @gets_count += 1
    raise @exception
  end

  def closed?
    @closed
  end

  def close
    @closed = true
  end
end

class MessageListenerTest < Test::Unit::TestCase

  FakeRenderArbiter = Struct.new :queue

  def setup
    @socket_path = "/tmp/message_listener_test.socket"
    FileUtils.rm_f @socket_path
    listening_socket = UNIXServer.open @socket_path
    listening_socket.close_on_exec = true
    listening_socket.listen 1
    @writing_socket = UNIXSocket.open @socket_path
    @writing_socket.close_on_exec = true
    @reading_socket = listening_socket.accept
    @reading_socket.close_on_exec = true
    @render_arbiter = FakeRenderArbiter.new Queue.new
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
    listener = Honcho::MessageListener.new @reading_socket, @render_arbiter, @response_waiter, focus_manager
    assert_equal "message_listener_test", listener.application
  end

  def test_queue_render_requests_for_active_application
    focus_manager = HasFocusFocusManager.new
    listener = Honcho::MessageListener.new @reading_socket, @render_arbiter, @response_waiter, focus_manager
    listener.listen_and_process_messages
    write_render_request_to_socket "12345678901234"
    assert_equal 1, @render_arbiter.queue.size
    write_render_request_to_socket "1234"
    assert_equal 2, @render_arbiter.queue.size
    assert_equal "12345678901234", @render_arbiter.queue.pop
  end

  def test_ignore_render_request_for_inactive_application
    focus_manager = DoesNotHaveFocusFocusManager.new
    listener = Honcho::MessageListener.new @reading_socket, @render_arbiter, @response_waiter, focus_manager
    listener.listen_and_process_messages
    write_render_request_to_socket "12345678901234"
    write_render_request_to_socket "12345678901234"
    assert_equal 0, @render_arbiter.queue.size
  end

  def test_resume_event_loop_on_keep_focus_response
    focus_manager = HasFocusFocusManager.new
    listener = Honcho::MessageListener.new @reading_socket, @render_arbiter, @response_waiter, focus_manager
    listener.listen_and_process_messages
    write_keep_focus_response
    assert_kind_of Honcho::Message, @response_waiter.wait
  end

  def test_application_has_closed_socket_with_econnreset
    focus_manager = HasFocusFocusManager.new
    socket = ExceptionSocket.new Errno::ECONNRESET
    listener = Honcho::MessageListener.new socket, @render_arbiter, @response_waiter, focus_manager
    listener.listen_and_process_messages
    sleep 0.3
    assert_equal 1, socket.gets_count
    assert listener.socket.closed?
  end

  def test_application_has_closed_socket_with_ebadf
    focus_manager = HasFocusFocusManager.new
    socket = ExceptionSocket.new Errno::EBADF
    listener = Honcho::MessageListener.new socket, @render_arbiter, @response_waiter, focus_manager
    listener.listen_and_process_messages
    sleep 0.3
    assert_equal 1, socket.gets_count
    assert listener.socket.closed?
  end

  def test_application_has_closed_socket_with_ioerror
    focus_manager = HasFocusFocusManager.new
    socket = ExceptionSocket.new IOError
    listener = Honcho::MessageListener.new socket, @render_arbiter, @response_waiter, focus_manager
    listener.listen_and_process_messages
    sleep 0.3
    assert_equal 1, socket.gets_count
    assert listener.socket.closed?
  end
end

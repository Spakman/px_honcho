require "test/unit"
require "socket"
require "fileutils"
require "thread"
require "#{File.dirname(__FILE__)}/../lib/render_request_listener"

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

class Honcho::RenderRequestListener
  attr_reader :application
end

class RenderRequestListenerTest < Test::Unit::TestCase
  def setup
    @socket_path = "/tmp/render_request_listener_test.socket"
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

  def test_set_application_name
    focus_manager = HasFocusFocusManager.new
    listener = Honcho::RenderRequestListener.new @reading_socket, @queue, focus_manager
    assert_equal "render_request_listener_test", listener.application
  end

  def test_queue_requests_for_active_application
    focus_manager = HasFocusFocusManager.new
    listener = Honcho::RenderRequestListener.new @reading_socket, @queue, focus_manager
    Thread.new do
      listener.listen_and_queue_requests
    end
    sleep 1
    @writing_socket << "<render 14>\n"
    @writing_socket << "12345678901234"
    sleep 1
    assert_equal 1, @queue.size
    @writing_socket << "<render 4>\n"
    @writing_socket << "1234"
    sleep 1
    assert_equal 2, @queue.size
    assert_equal "12345678901234", @queue.pop
  end

  def test_ignore_request_for_inactive_application
    focus_manager = DoesNotHaveFocusFocusManager.new
    listener = Honcho::RenderRequestListener.new @reading_socket, @queue, focus_manager
    Thread.new do
      listener.listen_and_queue_requests
    end
    sleep 1
    @writing_socket << "<render 14>\n"
    @writing_socket << "12345678901234"
    sleep 1
    @writing_socket << "<render 14>\n"
    @writing_socket << "12345678901234"
    sleep 1
    assert_equal 0, @queue.size
  end
end

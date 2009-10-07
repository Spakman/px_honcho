require "test/unit"
require "socket"
require "fileutils"
require "thread"
require "#{File.dirname(__FILE__)}/../lib/evdev_listener"
require "#{File.dirname(__FILE__)}/../lib/application_manager"

Thread.abort_on_exception = true

class Honcho::ApplicationManager
  remove_const :APPLICATION_BASE
  APPLICATION_BASE = File.dirname(__FILE__)
  attr_reader :applications
end

class ApplicationManagerTest < Test::Unit::TestCase
  FakeRenderArbiter = Struct.new :queue
  FakeEventListener = Struct.new :queue

  def teardown
    FileUtils.rm_f "/tmp/simple.socket"
    FileUtils.rm_f "/tmp/just_as_simple.socket"
    sleep 1
    @manager.shutdown
  end

  def test_load_first_application
    @manager = Honcho::ApplicationManager.new FakeRenderArbiter.new(Queue.new), nil
    @manager.load_application "simple"
    assert_equal 1, @manager.applications.size
    assert_equal "simple", @manager.current_application[:name]
    assert !@manager.current_application[:socket].closed?
  end

  def test_switch_application_on_application_load
    @manager = Honcho::ApplicationManager.new FakeRenderArbiter.new(Queue.new), nil
    @manager.load_application "simple"
    @manager.load_application "just_as_simple"
    assert_equal 2, @manager.applications.size
    assert_equal "just_as_simple", @manager.current_application[:name]
    assert !@manager.applications["simple"][:socket].closed?
    assert !@manager.current_application[:socket].closed?
    assert @manager.has_focus?("just_as_simple")
    assert !@manager.has_focus?("simple")
  end

  def test_load_already_loaded_application
    @manager = Honcho::ApplicationManager.new FakeRenderArbiter.new(Queue.new), nil
    @manager.load_application "simple"
    @manager.load_application "just_as_simple"
    @manager.load_application "simple"
    assert_equal 2, @manager.applications.size
    assert_equal "simple", @manager.current_application[:name]
    assert @manager.has_focus?("simple")
  end

  def test_event_loop
    queue = Queue.new
    queue << Honcho::InputEvent.new(:top_left)
    queue << Honcho::InputEvent.new(:jog_wheel_left)
    @manager = Honcho::ApplicationManager.new FakeRenderArbiter.new(Queue.new), FakeEventListener.new(queue)
    @manager.load_application "simple"
    Thread.new do
      @manager.event_loop
    end
    sleep 0.2
    # Should still have one event on the queue, since the event loop should be waiting for a response
    assert_equal 1, queue.size
    # the simple program will send a response on SIGUSR1
    Process.kill "USR1", @manager.current_application[:pid]
    sleep 0.2
    assert_empty queue
  end
end

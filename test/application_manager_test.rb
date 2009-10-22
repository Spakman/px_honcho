require "test/unit"
require "socket"
require "fileutils"
require "thread"
require_relative "../lib/evdev_listener"
require_relative "../lib/application_manager"

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
    FileUtils.rm_f "/tmp/no_respond.socket"
    FileUtils.rm_f "/tmp/respond_keep_focus.socket"
    sleep 1
    @manager.shutdown
  end

  def test_load_first_application
    @manager = Honcho::ApplicationManager.new FakeRenderArbiter.new(Queue.new), nil
    @manager.load_application "no_respond"
    assert_equal 1, @manager.applications.size
    assert_equal "no_respond", @manager.applications.active[:name]
    assert !@manager.applications.active[:socket].closed?
  end

  def test_switch_application_on_application_load
    @manager = Honcho::ApplicationManager.new FakeRenderArbiter.new(Queue.new), nil
    @manager.load_application "no_respond"
    @manager.load_application "respond_keep_focus"
    assert_equal 2, @manager.applications.size
    assert_equal "respond_keep_focus", @manager.applications.active[:name]
    assert !@manager.applications.running?("no_respond")[:socket].closed?
    assert !@manager.applications.active[:socket].closed?
    assert @manager.has_focus?("respond_keep_focus")
    assert !@manager.has_focus?("no_respond")
  end

  def test_load_already_loaded_application
    @manager = Honcho::ApplicationManager.new FakeRenderArbiter.new(Queue.new), nil
    @manager.load_application "no_respond"
    @manager.load_application "respond_keep_focus"
    @manager.load_application "no_respond"
    assert_equal 2, @manager.applications.size
    assert_equal "no_respond", @manager.applications.active[:name]
    assert @manager.has_focus?("no_respond")
  end

  def test_event_loop
    queue = Queue.new
    queue << Honcho::InputEvent.new(:top_left)
    queue << Honcho::InputEvent.new(:jog_wheel_left)
    @manager = Honcho::ApplicationManager.new FakeRenderArbiter.new(Queue.new), FakeEventListener.new(queue)
    @manager.load_application "no_respond"
    Thread.new do
      @manager.event_loop
    end
    sleep 0.2
    # Should still have one event on the queue, since the event loop should be waiting for a response
    assert_equal 1, queue.size
    # the no_respond program will send a response on SIGUSR1
    Process.kill "USR1", @manager.applications.active[:pid]
    sleep 0.2
    assert_empty queue
  end

  def test_act_on_closing_response
    queue = Queue.new
    @manager = Honcho::ApplicationManager.new FakeRenderArbiter.new(Queue.new), FakeEventListener.new(queue)
    @manager.load_application "respond_keep_focus"
    @manager.load_application "no_respond"
    @manager.act_on_response Honcho::Message.new(:closing)
    assert_equal 1, @manager.applications.size
    assert_equal "respond_keep_focus", @manager.applications.active[:name]
    assert @manager.has_focus?("respond_keep_focus")
  end
end

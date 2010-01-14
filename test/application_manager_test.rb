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
    FileUtils.rm_f "/tmp/fake_messier.socket"
    FileUtils.rm_f "/tmp/fake_clock.socket"
    FileUtils.rm_f "/tmp/fake_mozart.socket"
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
    @manager.load_application "fake_messier"
    assert_equal 2, @manager.applications.size
    assert_equal "fake_messier", @manager.applications.active[:name]
    assert !@manager.applications.running?("no_respond")[:socket].closed?
    assert !@manager.applications.active[:socket].closed?
    assert @manager.has_focus?("fake_messier")
    assert !@manager.has_focus?("no_respond")
  end

  def test_load_already_loaded_application_in_foreground
    @manager = Honcho::ApplicationManager.new FakeRenderArbiter.new(Queue.new), nil
    @manager.load_application "no_respond"
    @manager.load_application "fake_messier"
    @manager.load_application "no_respond"
    assert_equal 2, @manager.applications.size
    assert_equal "no_respond", @manager.applications.active[:name]
    assert @manager.has_focus?("no_respond")
  end

  def test_load_application_in_background
    @manager = Honcho::ApplicationManager.new FakeRenderArbiter.new(Queue.new), nil
    @manager.load_application "no_respond"
    @manager.load_application "fake_messier", has_focus: false
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
    @manager.load_application "fake_messier"
    @manager.load_application "no_respond"
    @manager.act_on_response Honcho::Message.new(:closing)
    assert_equal 1, @manager.applications.size
    assert_equal "fake_messier", @manager.applications.active[:name]
    assert @manager.has_focus?("fake_messier")
  end

  def test_act_on_passfocus_response_without_params
    queue = Queue.new
    @manager = Honcho::ApplicationManager.new FakeRenderArbiter.new(Queue.new), FakeEventListener.new(queue)
    @manager.load_application "fake_messier"
    @manager.act_on_response Honcho::Message.new(:passfocus, application: "fake_clock")
    assert_equal 2, @manager.applications.size
    assert_equal "fake_clock", @manager.applications.active[:name]
    assert @manager.has_focus?("fake_clock")
  end

  def test_act_on_passfocus_response_with_params
    queue = Queue.new
    @manager = Honcho::ApplicationManager.new FakeRenderArbiter.new(Queue.new), FakeEventListener.new(queue)
    @manager.load_application "fake_messier"
    @manager.act_on_response Honcho::Message.new(:passfocus, application: "fake_mozart", "method" => "play_ids", "params" => "1,2,3")
    assert_equal 2, @manager.applications.size
    assert_equal "fake_mozart", @manager.applications.active[:name]
    assert @manager.has_focus?("fake_mozart")
    assert_equal "method: play_ids\nparams: 1,2,3", File.read("fake_mozart_params.test")
    FileUtils.rm "fake_mozart_params.test"
  end

  def test_act_on_passfocus_response_without_any_body
    queue = Queue.new
    @manager = Honcho::ApplicationManager.new FakeRenderArbiter.new(Queue.new), FakeEventListener.new(queue)
    @manager.load_application "fake_clock"
    @manager.load_application "fake_messier"
    @manager.load_application "fake_mozart"
    @manager.act_on_response Honcho::Message.new(:passfocus)
    assert_equal 3, @manager.applications.size
    assert_equal "fake_messier", @manager.applications.active[:name]
    assert @manager.has_focus?("fake_messier")
    assert_equal "fake_mozart", @manager.applications.first[:name]
  end
end

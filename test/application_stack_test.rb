require "test/unit"
require "stringio"
require_relative "../lib/application_stack"

class ApplicationStackTest < Test::Unit::TestCase
  def setup
    @stack = Honcho::ApplicationStack.new
    @socket = StringIO.new
    @pid = fork do
      sleep 5
    end
    # let's only only try to close 'three' because that's the only one with a real process!
    @stack << { :name => 'one', :socket => @socket } << { :name => 'two', :socket => @socket } << { :name => 'three', :socket => @socket, :pid => @pid }
  end

  def test_switch_applications
    @stack.active = 'one'
    assert_equal 'one', @stack.active[:name]
    assert_equal 3, @stack.size
  end

  def test_running
    assert @stack.running?('one')
    assert !@stack.running?('four')
  end

  def test_close
    @stack.close 'three'
    assert_equal 'two', @stack.active[:name]
    assert !@stack.running?('three')
    assert @socket.closed?
  end

  def test_pid_is_reaped_on_close
    assert_equal @pid.to_s, `ps -o pid= #{@pid}`.chomp
    @stack.close 'three'
    sleep 1
    assert_empty `ps -o pid= #{@pid}`.chomp
  end

  def test_close_active
    @stack.close_active
    assert_equal 'two', @stack.active[:name]
    assert !@stack.running?('three')
    assert @socket.closed?
  end

  def test_get
    assert_equal 'two', @stack.get("two")[:name]
  end

  def test_move_active_to_bottom
    assert_equal 'two', @stack.move_active_to_bottom[:name]
    assert_equal 'three', @stack.first[:name]
    assert_equal 'two', @stack.active[:name]
  end
end

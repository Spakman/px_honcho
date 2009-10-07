require "test/unit"
require "stringio"
require "#{File.dirname(__FILE__)}/../lib/application_stack"

class ApplicationStackTest < Test::Unit::TestCase
  def setup
    @stack = Honcho::ApplicationStack.new
    @socket = StringIO.new
    @stack << { :name => 'one', :socket => @socket } << { :name => 'two', :socket => @socket } << { :name => 'three', :socket => @socket }
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

  def test_close_active
    @stack.close_active
    assert_equal 'two', @stack.active[:name]
    assert !@stack.running?('three')
    assert @socket.closed?
  end

  def test_get
    assert_equal 'two', @stack.get("two")[:name]
  end
end

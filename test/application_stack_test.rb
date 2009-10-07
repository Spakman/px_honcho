require "test/unit"
require "#{File.dirname(__FILE__)}/../lib/application_manager"

class ApplicationStackTest < Test::Unit::TestCase
  def setup
    @stack = Honcho::ApplicationStack.new
    @stack << { :name => 'one' } << { :name => 'two' } << { :name => 'three' }
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

  def test_closed
    @stack.closed 'three'
    assert_equal 'two', @stack.active[:name]
    assert !@stack.running?('three')
  end

  def test_close_active
    @stack.close_active
    assert_equal 'two', @stack.active[:name]
    assert !@stack.running?('three')
  end
end

require "test/unit"
require_relative "../lib/response_waiter"

class ResponseWaiterTest < Test::Unit::TestCase

  def setup
    @fifo_path = "/tmp/render_arbiter_test.fifo"
  end

  def test_wait_for_response
    @waiter = Honcho::ResponseWaiter.new
    response = nil
    Thread.new do
      response = @waiter.wait
    end
    sleep 0.1
    assert @waiter.waiting
    assert_nil response
    @waiter.signal "done"
    sleep 0.1
    assert response
    refute @waiter.waiting
  end
end

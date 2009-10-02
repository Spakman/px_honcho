require "test/unit"
require "socket"
require "fileutils"
require "#{File.dirname(__FILE__)}/../lib/render_arbiter"

class RenderArbiterTest < Test::Unit::TestCase

  def setup
    @fifo_path = "/tmp/render_arbiter_test.fifo"
  end

  def teardown
    FileUtils.rm_f @fifo_path
  end

  def test_send_requests
    queue = [ "DEF", "BC", "A" ]
    arbiter = Honcho::RenderArbiter.new @fifo_path, queue
    arbiter.send_render_requests
    sleep 1
    assert_equal "<render 1>\nA<render 2>\nBC<render 3>\nDEF", File.read(@fifo_path)
  end
end

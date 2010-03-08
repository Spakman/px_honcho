require "test/unit"
require "socket"
require "fileutils"
require_relative "../lib/render_arbiter"

class RenderArbiterTest < Test::Unit::TestCase

  def setup
    @fifo_path = "/tmp/render_arbiter_test.fifo"
  end

  def teardown
    FileUtils.rm_f @fifo_path
  end

  def test_send_requests
    queue = Queue.new
    queue << "A"
    queue << "BC"
    queue << "DEF"
    arbiter = Honcho::RenderArbiter.new @fifo_path, queue
    arbiter.send_render_requests
    sleep 0.3
    assert_equal "<render 1>\nA<render 2>\nBC<render 3>\nDEF", File.read(@fifo_path)
  end

  def test_pipe_is_closed_on_exec
    arbiter = Honcho::RenderArbiter.new @fifo_path, nil
    pid = fork { exec "sleep 3" }
    sleep 0.5

    assert_equal 3, `ls /proc/#{pid}/fd/ | wc -l`.chomp.to_i
  end
end

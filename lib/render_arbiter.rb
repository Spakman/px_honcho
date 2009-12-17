# Copyright (C) 2009 Mark Somerville <mark@scottishclimbs.com>
# Released under the General Public License (GPL) version 3.
# See COPYING

require "thread"
require_relative "message"

module Honcho
  class RenderArbiter
    attr_reader :queue

    def initialize(fifo_path, render_queue)
      @queue = render_queue
      @pipe = File.open fifo_path, "a+"
    end

    # Loops in a thread, sending render requests to Rembrandt as soon as
    # they are available.
    def send_render_requests
      Thread.new do
        loop do
          request = @queue.pop
          @pipe << Message.new(:render, request)
          @pipe.flush
        end
      end
    end
  end
end

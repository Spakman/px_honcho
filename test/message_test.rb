require "test/unit"
require_relative "../lib/message"

class MessageTest < Test::Unit::TestCase
  def test_to_s
    assert_equal "<keepfocus 0>\n", Honcho::Message.new(:keepfocus).to_s
    assert_equal "<passfocus 50>\napplication: mozart\nmethod: play_ids\nparams: 1,2,3", Honcho::Message.new(:passfocus, { application: "mozart", method: "play_ids", params: "1,2,3" }).to_s
    assert_equal "<render 18>\n<text>hello</text>", Honcho::Message.new(:render, "<text>hello</text>").to_s
  end

  def test_body_keys_are_symbolised
    body = "application: mozart\nmethod: queue_ids"
    message = Honcho::Message.new(:passfocus, body)
    assert_equal [ :application, :method ], message.body.keys.sort
  end
end

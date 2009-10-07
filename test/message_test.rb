require "test/unit"
require "#{File.dirname(__FILE__)}/../lib/message"

class MessageTest < Test::Unit::TestCase
  def test_to_s
    assert_equal "<keepfocus 0>\n", Honcho::Message.new(:keepfocus).to_s
    assert_equal "<passfocus 19>\napplication: my_app", Honcho::Message.new(:passfocus, { application: "my_app" }).to_s
    assert_equal "<render 18>\n<text>hello</text>", Honcho::Message.new(:render, "<text>hello</text>").to_s
  end
end

require "test/unit"
require "fileutils"
require_relative "../lib/backlight_controller"

class BacklightControllerTest < Test::Unit::TestCase

  def setup
    @backlight_filepath = "/tmp/render_arbiter_test.fifo"
    @backlight = Honcho::BacklightController.new(@backlight_filepath, 2)
  end

  def value_in_file
    File.read(@backlight_filepath).to_i
  end

  def teardown
    FileUtils.rm_f @backlight_filepath
  end

  def test_on_and_off_checks
    assert @backlight.off?
    @backlight.on!
    assert @backlight.on?
  end

  def test_turns_of_after_a_while
    @backlight.on!
    assert @backlight.on?
    assert_equal 1, value_in_file
    sleep 3
    assert @backlight.off?
    assert_equal 0, value_in_file
  end

  def test_off_time_is_reset_when_on_is_called_again
    @backlight.on!
    assert @backlight.on?
    assert_equal 1, value_in_file
    sleep 1.5
    @backlight.on!
    sleep 1.5
    assert @backlight.on?
    assert_equal 1, value_in_file
    sleep 1
    assert @backlight.off?
    assert_equal 0, value_in_file
  end

  def test_turn_off_manually
    @backlight.on!
    assert @backlight.on?
    assert_equal 1, value_in_file
    @backlight.off!
    assert @backlight.off?
    assert_equal 0, value_in_file
  end
end

require 'rubactive'
require_relative 'testutil'

class RubactiveUseCaseTests < Test::Unit::TestCase
  include Rubactive

  MIN=0
  MAX=100
  DEFAULT=50

  def setup
    # What our program knows about the current setting.
    @hardware_setting = TimeVaryingValue.starting_with(DEFAULT)

    # User-initiated deltas to the hardware setting
    @deltas = DiscreteValueStream.manual

    # Convert a stream of deltas to a stream of actual values
    @user_changes = DiscreteValueStream.follows(@deltas) do |delta|
      delta + @hardware_setting.current
    end

    # Callback to code that manipulates hardware.
    @user_changes.on_addition do |value|
      # The code talks to the real hardware and also sets the authoritative value:
      @hardware_setting.change_to(value)
    end

    #Pretend this is the value of a slider or something
    @value_displayed = TimeVaryingValue.follows(@hardware_setting)
  end

  should "propagate user changes" do
    @deltas.add_value(5)

    assert_equal(55, @hardware_setting.current)
    assert_equal(55, @value_displayed.current)
  end

  should "propagate and obey hardware changes" do
    @hardware_setting.change_to(80)

    assert_equal(80, @hardware_setting.current)
    assert_equal(80, @value_displayed.current)

    @deltas.add_value(5)

    assert_equal(85, @hardware_setting.current)
    assert_equal(85, @value_displayed.current)
  end
end



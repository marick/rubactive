require 'rubactive'
require_relative 'testutil'

class Fixnum
  # A useful N-argument method for testing
  def max3(other1, other2)
    [self, other1, other2].max
  end
end


class RubactiveTests < Test::Unit::TestCase
  include Rubactive

  context "time-varying values" do
    should "hold values" do
      v = TimeVaryingValue.starting_with(3)
      assert_equal(3, v.current)
      v.change_to(4)
      assert_equal(4, v.current)
    end

    context "following" do

      should "allow other time-varying values" do
        origin = TimeVaryingValue.starting_with(3)
        destination = TimeVaryingValue.follows(origin) { |o| o + 1}
        assert_equal(4, destination.current)
        origin.change_to(4)
        assert_equal(5, destination.current)
      end

      should "allow chains" do
        origin = TimeVaryingValue.starting_with(3)
        middle = TimeVaryingValue.follows(origin) { |o| o + 1}
        destination = TimeVaryingValue.follows(middle) { |o| o + 1}

        assert_equal(4, middle.current)
        assert_equal(5, destination.current)

        origin.change_to(40)
        assert_equal(41, middle.current)
        assert_equal(42, destination.current)
      end

      should "allow discrete value streams" do
        changes = DiscreteValueStream.manual
        tracker = TimeVaryingValue.tracks_stream(changes, 88)
        assert_equal(88, tracker.current)
        changes.add_value(5)
        assert_equal(5, tracker.current)
      end
    end

    context "implicit creation" do

      should "generates value calculation from method-missing" do
        origin = TimeVaryingValue.starting_with(8)
        destination = origin + 1
        assert_equal(9, destination.current)
        assert_equal(TimeVaryingValue, destination.class)

        origin.change_to(33)
        assert_equal(34, destination.current)
      end

      should "work with multi-argument methods" do
        assert_equal(3, 1.max3(2, 3))

        origin = TimeVaryingValue.starting_with(2)
        other = origin * -1
        final = origin.max3(8, other)
        assert_equal(8, final.current)

        origin.change_to(100)
        assert_equal(100, final.current)

        origin.change_to(-222)
        assert_equal(222, final.current)
      end
    end
  end

  context "discrete value streams" do
    should "remember their most recent value" do
      s = DiscreteValueStream.manual
      s.add_value(33)
      assert_equal(33, s.most_recent_value)
    end

    should "start out with a null-like value" do
      s = DiscreteValueStream.manual
      assert_equal(:no_value_at_all, s.most_recent_value)
      assert_true(true, s.empty?)
    end

    should "be able to create new event streams from old" do
      stream = DiscreteValueStream.manual
      transformed = DiscreteValueStream.follows(stream) { |s|
        s + 1
      }
      stream.add_value(33)
      assert_equal(34, transformed.most_recent_value)
    end

    should "be able to create streams implicitly" do
      stream = DiscreteValueStream.manual
      transformed = stream + 1
      assert_equal(DiscreteValueStream, transformed.class)

      stream.add_value(33)
      assert_equal(34, transformed.most_recent_value)
    end
  end

  ### Behavior common to both types of value-holders
  ### Not a public API

  context "Reactive Nodes" do
    should "take a block that calculates their value" do
      n = ReactiveNode.blank
      n.value=5
      assert_equal(5, n.value)
    end

    should "be able to depend on other nodes" do
      before = ReactiveNode.blank
      before.value = 5

      after = ReactiveNode.follows(before) do |b|
        1 + b
      end
      after.recalculate
      assert_equal(6, after.value)

      before.value = 88
      assert_equal(89, after.value)
    end

    should "be able to depend on a combination of nodes" do
      a_node = ReactiveNode.blank
      a_node.value = 1

      b_node = ReactiveNode.blank
      b_node.value = 10

      captured = 100

      combiner = ReactiveNode.follows(a_node, b_node) do |a,b|
        a+b+captured
      end

      combiner.recalculate
      assert_equal(111, combiner.value)

      a_node.value = 20000
      assert_equal(20110, combiner.value)

      # unsurprisingly, changing the plain variable triggers no propagation
      captured = -a_node.value
      assert_equal(20110, combiner.value)

      b_node.value = 88
      assert_equal(88, combiner.value)
    end

    should "follow a variable if no block given" do
      before = ReactiveNode.blank
      after = ReactiveNode.follows(before)
      before.value = 88
      assert_equal(88, after.value)

    end

    should "be able to generate nodes implicitly" do
      origin = ReactiveNode.blank
      origin.value = 8
      destination = origin + 1
      destination.recalculate
      assert_equal(9, destination.value)

      origin.value=33
      assert_equal(34, destination.value)

      final_destination = destination + origin
      final_destination.recalculate
      assert_equal(67, final_destination.value)

      origin.value=1
      assert_equal(2, destination.value)
      assert_equal(3, final_destination.value)
    end

    should "capture many types of value-containing-things" do
      origin = ReactiveNode.blank
      other = ReactiveNode.blank
      other.value = 10

      captured = 100
      destination = origin + captured + other + 1

      origin.value=1000
      assert_equal(1111, destination.value)

      captured = 999999  # This does not trigger update - no surprise
      assert_equal(1111, destination.value)

      # But it also has no effect on any future updates.
      origin.value=2000
      assert_equal(2111, destination.value)
    end

    context "callbacks to update the outside world" do

      should "happen on recalculation" do
        origin = ReactiveNode.blank
        destination = ReactiveNode.follows(origin) {|o| o.to_s.upcase.to_sym}

        triggered = false
        destination.on_change do | value |
          triggered = value
        end

        origin.value = :new_value

        assert_equal(:NEW_VALUE, triggered)
      end

      should "happen on value-setting" do
        n = ReactiveNode.blank

        triggered = false
        n.on_change do | value |
          triggered = value
        end

        n.value = :new_value
        assert_equal(:new_value, triggered)
      end
    end
  end


end

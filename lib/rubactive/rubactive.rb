require 'forwardable'

# Rubactive provides two kinds of values-that-react-to-changes-in-other-values.
#
# Sometimes you want to think of the changing value as being something
# that "magically" changes over time (typically in reaction to changes
# in other values). That perspective is implemented by TimeVaryingValue.
#
# Sometimes you want to think of a stream of unchanging values that
# "magically" arrive (often in reaction to values appearing in other
# streams). That perspective is implemented by DiscreteValueStream. 
#


module Rubactive
  class ReactiveNode # :nodoc: 
    # This should probably be a delegate instead of superclass
    # because the subclasses don't want all of the methods
    # (but the tests do)
    private_class_method :new

    def self.follows(*earlier_nodes, &updater)
      new(*earlier_nodes, &updater)
    end

    attr_reader :value

    DEFAULT_VALUE = :no_value_at_all

    def initialize(*earlier_nodes, &recalculator)
      @value = DEFAULT_VALUE
      @recalculator = recalculator || ->val {val}
      @later_nodes = []
      @earlier_nodes = earlier_nodes
      @change_callback = ->ignored{}
      tell_earlier_nodes_about_me(earlier_nodes)
    end

    def tell_earlier_nodes_about_me(earlier_nodes)
      earlier_nodes.each do |e|
        e.this_node_is_later_than_you(self) if e.is_a?(ReactiveNode)
      end
    end

    def this_node_is_later_than_you(this_node)
      @later_nodes << this_node
    end

    def recalculate
      propagate(@recalculator.call(*just_values(@earlier_nodes)))
    end

    def value=(new_value)
      propagate(new_value)
    end

    # When the value of this variable changes, call the block argument.
    def on_change(&block)
      @change_callback = block
    end

    def propagate(value)
      @value = value
      @change_callback.(value)
      @later_nodes.each do |node|
        node.recalculate
      end
    end

    def method_missing(message, *args)
      recalculator = lambda do |*just_values|
        receiver = just_values.shift
        receiver.send(message, *just_values)
      end
      self.class.follows(self, *args, &recalculator)
    end

    def just_values(args)
      args.collect do |arg|
        if arg.is_a?(ReactiveNode)
          arg.value
        else
          arg
        end
      end
    end

    # test_support

    def self.blank
      follows() {}
    end

  end

  # A TimeVaryingValue represents a value that might "mysteriously"
  # change each time you look at it.
  #
  # The current value can change in three ways:
  # 
  # * Explicitly, via change_to. That's no different than setting an attribute of any
  #   sort of object.
  #
  # * It might have been created to "follow" other time-varying values. In that case,
  #   it will react to any of their changes by recalculating itself (in a way
  #   defined when it was created.)
  #
  # * It might have been created to follow a DiscreteValueStream. In that case, any
  #   value added to the stream becomes the time-varying value's current value.
  #   
  # There is a different constructor for each of the above cases. In addition, variables
  # can be implicity created by sending unrecognized messages to other time-varying values. 
  # 
  #    origin = TimeVaryingValue.starting_with(5)
  #    follower = origin + 1
  #    follower #=> 6
  #    
  #    origin.change_to(700)
  #    follower #=> 701
  class TimeVaryingValue < ReactiveNode
    # Create a value that changes as the values it depends upon change.
    # 
    # When any followed variables change, the block is called with their current
    # values. The result becomes the current value for this TimeVaryingValue.
    #
    # Example: 
    #   verb = TimeVaryingValue.starting_with("vote")
    #   adverb = TimeVaryingValue.starting_with("early")
    #   tracker = TimeVaryingValue.follows(verb, adverb) { | v, a | "#{v} #{a}!" }
    #   tracker.current #=> "vote early!"
    #   
    #   adverb.change_to("often") 
    #   tracker.current #=> "vote often!"
    #
    # If no block is given, this value should be following only one other. 
    # It adopts that other value whenever it changes.
    #--
    # Defined here so that I can write special-purpose documentation.
    def self.follows(*values, &block)
      super
    end

    # Create a new TimeVaryingValue.
    #
    # Since the returned instance follows nothing, only change_to can
    # be used to change its value.
    def self.starting_with(initial_value)
      follows { initial_value }
    end

    # Create a time-varying value that follows the latest value in a stream.
    #
    # The first argument must be a DiscreteValueStream. Whenever that stream
    # has a new value added, the time-varying value changes to match. 
    #
    # The time-varying value always starts with the given initial_value, even
    # if stream has previously had some values added to it. 
    #--
    # Flapjax startsWith
    def self.tracks_stream(value_stream, initial_value)
      retval = follows(value_stream)
      retval.change_to(initial_value)
      retval
    end

    # Retrieve the current value.
    #
    # Earlier values are inaccessible.
    def current; value; end

    # Change the current value.
    def change_to(new_value); self.value=new_value; end

    def initialize(*earlier_nodes, &recalculator) # :nodoc:
      super
      recalculate
    end

  end

  # A DiscreteValueStream represents a stream of values. When a value is added to the stream,
  # other DiscreteValueStreams may react if they follow this stream.
  #
  # Streams are explicitly created with DiscreteValueStream.manual or
  # DiscreteValueStream.follows.  In the first case, values are added
  # only with add_value. In the second, values can also be added in
  # reaction to the streams being followed.
  #
  # Streams can also be implicity created by sending other streams unrecognized messages.
  # 
  #    origin = DiscreteValueStream.manual
  #    follower = origin + 1
  #
  # The previous definition of the follower stream is equivalent to this:
  #
  #    follower = DiscreteValueStream.follows(origin) { | o | + 1 }
  class DiscreteValueStream < ReactiveNode
    # Create a stream that reacts to one or more other streams.
    # 
    # The addition of values to any of the streams will cause the block
    # to be called with their most recent values. The result is added to
    # this stream (as with add_value).
    #
    # Example: 
    #   origin = DiscreteValueStream.manual
    #   follower = DiscreteValueStream.follows(origin) { | o | o+1 }
    #   origin.add_value(5)
    #   follower.most_recent_value #=> 6
    #
    # If no block is given, this stream should be following only one other stream.
    # The value just added to that stream is also added to this one.
    #--
    # Defined here so that I can write special-purpose documentation.
    def self.follows(*streams, &block)
      super
    end

    # Create an empty value stream
    # 
    # Use add_value to insert values into the stream.
    def self.manual
      follows {
        raise "Incorrect use of recalculation in a manual event stream"
      }
    end

    # Run a callback when a new value is added.
    #
    # This is an interface to the non-reactive world. When a new value is
    # added (whether with add_value or in reaction to a followed stream),
    # the callback is called and given that value. The callback will typically
    # do something with the value, like add it to a GUI.
    def on_addition(&callback); on_change(&callback); end


    # Retrieve last value added to the stream
    #
    # Earlier values are inaccessible.
    #
    # It is an error to ask for the value of an #empty? stream.
    def most_recent_value; @value; end

    # Place a new value on the stream
    def add_value(new_value)    # this?
      self.value = new_value
    end

    # True iff no value has ever been added to the stream.
    def empty?
      most_recent_value == DEFAULT_VALUE
    end
  end
end


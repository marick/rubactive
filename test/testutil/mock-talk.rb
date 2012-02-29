class Test::Unit::TestCase
  include RR::Adapters::TestUnit
end

# These methods are used to change the flow of control so that the
# test can state what is to happen before stating what the mock should
# receive.
class Test::Unit::TestCase
  def during(&block)
    # Use of global needed for current way of handling
    # listeners:
    #  listeners_to(@sut).run_methods {...}
    $what_runs_after_mock_setup = block
    self
  end

  def behold!
    yield
    @result = $what_runs_after_mock_setup.call
  end

  def listeners_to(object)
    klass = object.class.const_get("Listener")
    any_old_listener = klass.new
    object.add_listener(any_old_listener)

    # mock(any_old_listener).increase_setting
    mockable = mock(any_old_listener)

    def mockable.are_sent(&block)
      instance_eval(&block)
      $what_runs_after_mock_setup.call
    end
    mockable
  end

  def mocked(n = 1)
    if (n == 1)
      one_mock
    else
      (0...n).collect do
        one_mock
      end
    end
  end

  def one_mock
    core_object = Object.new
    mock_wrapper = mock(core_object)
    core_object.define_singleton_method(:is_sent) { mock_wrapper }
    core_object
  end


  def collaborators(*names)
    ensure_strings(names).each do | name |
      result = one_mock()
      self.instance_variable_set(instance_name(name), result)
    end
  end
  alias_method :collaborator, :collaborators


  private

  def ensure_strings(maybe_symbols)
    maybe_symbols.collect(&:to_s)
  end

  def instance_name(raw_name)
    "@" + raw_name.to_s
  end



end
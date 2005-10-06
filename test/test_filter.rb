# Code Generated by ZenTest v. 2.3.0
#                 classname: asrt / meth =  ratio%
#                    Filter:    3 /    4 =  75.00%

unless defined? $ZENTEST and $ZENTEST
require 'test/unit'
require 'protocol/filter'
require 'flexmock'
end

class TestFilter < Test::Unit::TestCase
  def setup
    pstack = FlexMock.new
    @filter = Filter.new(pstack)
  end

  def test_filter_in
    assert_equal("foo", @filter.filter_in("foo"))
  end

  def test_filter_out
    assert_equal("foo", @filter.filter_out("foo"))
  end

  def test_init
    assert_equal(true, @filter.init)
  end
end


# Code Generated by ZenTest v. 2.3.0
#                 classname: asrt / meth =  ratio%
#               DebugFilter:    2 /    3 =  66.67%

unless defined? $ZENTEST and $ZENTEST
require 'test/unit'
require 'log'
require 'protocol/debugfilter'
require 'flexmock'
end

class TestDebugFilter < Test::Unit::TestCase
  def setup
    @pstack = FlexMock.new
    @pstack.mock_handle(:conn) { 1 }
    @filter = DebugFilter.new(@pstack)
  end

  def test_filter_in
    assert_equal("foobar", @filter.filter_in("foobar"))
  end

  def test_filter_out
    assert_equal("foobar", @filter.filter_out("foobar"))
  end
end


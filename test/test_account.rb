# Code Generated by ZenTest v. 2.4.0
#                 classname: asrt / meth =  ratio%
#                   Account:    0 /    4 =   0.00%

unless defined? $ZENTEST and $ZENTEST
require 'test/unit'
require 'flexmock'
load 'mockengine.rb'
require 'core/account'
end

class TestAccount < Test::Unit::TestCase
  def setup
    $id = 0
  end

  def test_update
    assert_equal(nil,Account.new(5).update("foo"))
  end
end

# Number of errors detected: 1

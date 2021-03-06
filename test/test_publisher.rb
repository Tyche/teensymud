# Code Generated by ZenTest v. 2.3.0
#                 classname: asrt / meth =  ratio%
#                 Publisher:    8 /    4 = 200.00%

unless defined? $ZENTEST and $ZENTEST
require 'test/unit'
require 'utility/publisher'
end

class TestPublisher < Test::Unit::TestCase

  class A
    include Publisher
  end

  class B
    attr :msg
    def update(msg)
      @msg = msg
    end
  end

  def setup
    @obj1 = A.new
    @obj2 = B.new
    @obj3 = B.new
  end

  def test_publish
    assert(@obj1.subscribe(@obj2))
    assert(@obj1.subscribe(@obj3))
    assert(@obj1.publish("foo"))
    assert_equal("foo", @obj2.msg)
    assert_equal("foo", @obj3.msg)
  end

  def test_subscribe
    assert(@obj1.subscribe(@obj2))
    assert(@obj1.subscribe(@obj3))
    assert_equal(2, @obj1.subscriber_count)
  end

  def test_unsubscribe
    assert(@obj1.subscribe(@obj2))
    assert_equal(1, @obj1.subscriber_count)
    assert(@obj1.unsubscribe(@obj2))
    assert_equal(0, @obj1.subscriber_count)
  end

  def test_subscriber_count
    assert_equal(0, @obj1.subscriber_count)
    assert(@obj1.subscribe(@obj2))
    assert_equal(1, @obj1.subscriber_count)
  end

  def test_unsubscribe_all
    assert(@obj1.subscribe(@obj2))
    assert(@obj1.subscribe(@obj3))
    assert_equal(2, @obj1.subscriber_count)
    assert(@obj1.unsubscribe_all)
    assert_equal(0, @obj1.subscriber_count)
  end
end


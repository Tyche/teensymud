# Code Generated by ZenTest v. 2.3.0
#                 classname: asrt / meth =  ratio%
#                    Player:    0 /    8 =   0.00%

unless defined? $ZENTEST and $ZENTEST
require 'test/unit'
require 'log'
require 'db/properties'
require 'db/player'
require 'db/room'
require 'flexmock'
end

class TestPlayer < Test::Unit::TestCase
  def setup
    @id = 0
    $engine = FlexMock.new
    $engine.mock_handle(:world) {$engine}
    $engine.mock_handle(:db) {$engine}
    $engine.mock_handle(:mark) {false}
    $engine.mock_handle(:getid) {@id += 1}
    $engine.mock_handle(:add_event) {|*e| true}
    $engine.mock_handle(:eventmgr) {$engine}
    $engine.mock_handle(:ocmds) {$engine}
    $engine.mock_handle(:cmds) {$engine}
    $engine.mock_handle(:find) {[]}
    $engine.mock_handle(:get) {@r}
    @r = Room.new("Here")
    @p = Player.new("Tyche","tyche",nil)
  end

  def test_ass
    k = [:describe,:describe,:show,:show,:get,:get,:get,
      :drop,:drop,:drop,:timer,:timer,:timer,:foobar]
    m = FlexMock.new
    m.mock_handle(:kind) {k.shift}
    m.mock_handle(:from) {9}
    m.mock_handle(:msg) {}
    assert(@p.ass(m))
    assert(@p.ass(m))
    assert(@p.ass(m))
    assert(@p.ass(m))
    assert(@p.ass(m))
    assert_equal(nil,@p.ass(m))
  end

  def test_check_passwd
    assert_equal(true, @p.check_passwd("tyche"))
    assert_equal(false, @p.check_passwd("blah"))
  end

  def test_color
    assert_equal(false,@p.color)
  end

  def test_color_equals
    assert_equal(true,@p.color=true)
  end

  def test_disconnect
    assert_equal(nil,@p.disconnect)
  end

  def test_parse
    assert_equal(nil,@p.parse("hello"))
  end

  def test_sendto
    assert_equal(nil,@p.sendto("hello"))
  end

  def test_session
    assert_equal(nil,@p.session)
  end

  def test_session_equals
    assert_equal(5,@p.session=5)
  end

  def test_update
    m = FlexMock.new
    assert(@p.update(m))
  end
end


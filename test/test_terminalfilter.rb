# Code Generated by ZenTest v. 2.3.0
#                 classname: asrt / meth =  ratio%
#            TerminalFilter:    6 /    7 =  85.71%

unless defined? $ZENTEST and $ZENTEST
require 'test/unit'
require 'log'
require 'protocol/terminalfilter'
require 'flexmock'
end

class TestTerminalFilter < Test::Unit::TestCase
  def setup
    @conn = FlexMock.new
    @conn.mock_handle(:sendmsg) { true }
    @pstack = FlexMock.new
    @pstack.mock_handle(:conn) { @conn }
    @pstack.mock_handle(:echo_on) { false }
    @filter = TerminalFilter.new(@pstack)
  end

  def test_echo
    assert(true, @filter.echo("hiya"))
  end

  def test_filter_in
    assert_equal("[COLOR=black]black[RESET][UP 1][END]",
      @filter.filter_in("\e[30mblack\e[0m\e[A\e[4~"))
  end

  def test_filter_out
    assert_equal("\ttext\e[15;7Hfoo\e9Abar\e[1;1H",
      @filter.filter_out("[TAB]text[HOME 15,7]foo[UP 9]bar[HOME 1,1]"))
  end

  def test_init
    assert_equal(true, @filter.init)
  end

  def test_mode_eh
    assert_equal(:ground, @filter.mode?)
  end

  def test_set_mode
    assert_equal(:esc, @filter.set_mode(:esc))
  end
end


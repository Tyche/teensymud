#
# file::    debugfilter.rb
# author::  Jon A. Lambert
# version:: 2.6.0
# date::    10/04/2005
#
# This source code copyright (C) 2005 by Jon A. Lambert
# All rights reserved.
#
# Released under the terms of the TeensyMUD Public License
# See LICENSE file for additional information.
#

require 'protocol/filter'
require 'protocol/vt100codes'

# The DebugFilter class simply logs all that passes through it
#
class DebugFilter < Filter
  include VT100Codes
  # Construct filter
  #
  # [+pstack+] The ProtocolStack associated with this filter
  def initialize(pstack)
    super(pstack)
  end

  # The filter_in method filters input data
  # [+str+]    The string to be processed
  # [+return+] The filtered data
  def filter_in(str)
    return "" if str.nil? || str.empty?
    @pstack.log.debug("(#{@pstack.conn.object_id}) INPUT #{str.inspect}" )
=begin
    case str
    when /#{F5.sub(/\[/,"\\[")}/
      @pstack.conn.sendmsg(CSI + "1;21" + SS)
    when /#{F6.sub(/\[/,"\\[")}/
      @pstack.conn.sendmsg(ESOL)
    when /#{F7.sub(/\[/,"\\[")}/
      @pstack.conn.sendmsg(QCP)
    when /#{F8.sub(/\[/,"\\[")}/
      @pstack.conn.sendmsg(CSI + HOME)
    when /#{F9.sub(/\[/,"\\[")}/
      @pstack.conn.sendmsg(CSI + "15;40" + HOME + "Hello World")
    when /#{F10.sub(/\[/,"\\[")}/
      @pstack.conn.sendmsg(ES)
    end
=end
    str
  end

  # The filter_out method filters output data
  # [+str+]    The string to be processed
  # [+return+] The filtered data
  def filter_out(str)
    return "" if str.nil? || str.empty?
    @pstack.log.debug("(#{@pstack.conn.object_id}) OUTPUT #{str.inspect}" )
    str
  end

end

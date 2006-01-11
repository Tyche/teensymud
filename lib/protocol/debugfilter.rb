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

# The DebugFilter class simply logs all that passes through it
#
class DebugFilter < Filter
  logger 'DEBUG'

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
    log.debug("(#{@pstack.conn.object_id}) INPUT #{str.inspect}" )
    str
  end

  # The filter_out method filters output data
  # [+str+]    The string to be processed
  # [+return+] The filtered data
  def filter_out(str)
    return "" if str.nil? || str.empty?
    log.debug("(#{@pstack.conn.object_id}) OUTPUT #{str.inspect}" )
    str
  end

end

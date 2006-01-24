#
# file::    colorfilter.rb
# author::  Jon A. Lambert
# version:: 2.8.0
# date::    01/19/2006
#
# This source code copyright (C) 2005, 2006 by Jon A. Lambert
# All rights reserved.
#
# Released under the terms of the TeensyMUD Public License
# See LICENSE file for additional information.
#
$:.unshift "lib" if !$:.include? "lib"
$:.unshift "vendor" if !$:.include? "vendor"

require 'network/protocol/filter'
require 'bbcode'

# The ColorFilter class implements ANSI color (SGR) support.
#
# A Filter can keep state and partial data
class ColorFilter < Filter
  logger 'DEBUG'

  # Construct filter
  #
  # [+pstack+] The ProtocolStack associated with this filter
  def initialize(pstack)
    super(pstack)
  end

  # The filter_out method filters output data
  # [+str+]    The string to be processed
  # [+return+] The filtered data
  def filter_out(str)
    return "" if str.nil? || str.empty?
    if @pstack.color_on
      s = BBCode.bbcode_to_ansi(str)
    else
      s = BBCode.strip_bbcode(str)
    end
    return s
  end

end


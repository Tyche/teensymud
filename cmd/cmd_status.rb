#
# file::    cmd_status.rb
# author::  Jon A. Lambert
# version:: 2.5.3
# date::    09/21/2005
#
# This source code copyright (C) 2005 by Jon A. Lambert
# All rights reserved.
#
# Released under the terms of the TeensyMUD Public License
# See LICENSE file for additional information.
#
module Cmd

  # displays session information
  def cmd_status(args)
    message(:terminal)
    message(:termsize)
    message(:color)
    message(:echo)
    message(:zmp)
    sendto("Terminal: #{@terminal}")
    sendto("Terminal size: #{@termsize[0]} X #{@termsize[1]}")
    sendto("Colors toggled #{@color ? "[COLOR=magenta]ON[/COLOR]" : "OFF" }")
    sendto("Echo is #{@echo ? "ON" : "OFF" }")
    sendto("ZMP is #{@zmp ? "ON" : "OFF" }")
  end

end

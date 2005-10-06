#
# file::    cmd_color.rb
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

  # toggles colors on or off
  def cmd_color(args)
    @color ? @color = false : @color = true
    publish([:color,@color])
    sendto("Colors toggled #{@color ? "[COLOR=magenta]ON[/COLOR]" : "OFF" }")
  end

end

#
# file::    cmd_show.rb
# author::  Jon A. Lambert
# version:: 2.9.0
# date::    03/10/2006
#
# This source code copyright (C) 2005, 2006 by Jon A. Lambert
# All rights reserved.
#
# Released under the terms of the TeensyMUD Public License
# See LICENSE file for additional information.
#
module Cmd

  # displays object
  # Syntax:
  #   @show #<oid>|me
  # (ex. @show me)
  def cmd_show(args)
    case args
    when /#(\d+)|(me)/
      sendto($1 == 'me' ? self.inspect : get_object($1.to_i).inspect)
    else
      sendto("What??")
    end
  end

end

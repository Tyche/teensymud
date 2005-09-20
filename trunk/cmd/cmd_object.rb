#
# file::    cmd_object.rb
# author::  Jon A. Lambert
# version:: 2.2.0
# date::    08/29/2005
#
# This source code copyright (C) 2005 by Jon A. Lambert
# All rights reserved.
#
# Released under the terms of the TeensyMUD Public License
# See LICENSE file for additional information.
#
module Cmd

  # sets the description for an object (ex. @set #1 A beautiful rose.)
  def cmd_object(args)
    case args
    when /(.*)/
      $engine.world.db.put(Obj.new($1,@location))
      sendto("Ok.")
    else
      sendto("What!!?")
    end
  end

end

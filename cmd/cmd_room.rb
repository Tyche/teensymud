#
# file::    cmd_room.rb
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

  # creates a new room and autolinks the exits using the exit names provided.
  # (ex. @room My Room north south)
  def cmd_room(*args)
    case args[0]
    when /(.*) (.*) (.*)/
      d=Room.new($1)
      $world.db.put(d)
      $world.db.get(@location).exits[$2]=d.oid
      d.exits[$3]=$world.db.get(@location).oid
      sendto("Ok." + EOL)
    else
      sendto("say what??")
    end
  end

end

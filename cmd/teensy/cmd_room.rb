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
  def cmd_room(args)
    case args
    when /(.*) (.*) (.*)/
      d=Room.new($1)
      if d.nil?
        log.error "Unable to create room."
        sendto "System error: unable to create room."
        return
      end
      $engine.world.db.put(d)
      $engine.world.db.get(location).exits[$2]=d.id
      d.exits[$3]=$engine.world.db.get(location).id
      sendto("Ok.")
    else
      sendto("say what??")
    end
  end

end

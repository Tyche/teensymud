#
# file::    cmd_kill.rb
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

  # This kills a player anywhere - it's link death (30% chance)
  def cmd_kill(*args)
    case args[0]
    when nil
      sendto("Who do you want to kill?")
    else
      d = $world.find_player_by_name(args[0])
      if !d
        sendto("Can't find them.")
        return
      end
      if rand < 0.3
        $world.global_message(@name+" kills " + d.name)
        d.disconnect
        # $world.delete(d)  Dont delete player, it's annoying
      else
        $world.global_message(@name+" misses " + d.name)
      end
    end
  end

end

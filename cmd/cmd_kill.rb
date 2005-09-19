#
# file::    cmd_kill.rb
# author::  Jon A. Lambert
# version:: 2.3.0
# date::    08/31/2005
#
# This source code copyright (C) 2005 by Jon A. Lambert
# All rights reserved.
#
# Released under the terms of the TeensyMUD Public License
# See LICENSE file for additional information.
#
module Cmd

  # This kills a player anywhere - it's link death (30% chance)
  def cmd_kill(args)
    case args
    when nil, ""
      sendto("Who do you want to kill?")
    else
      d = $engine.world.db.find_player_by_name(args)
      if !d
        sendto("Can't find them.")
        return
      end
      if rand < 0.3
        sendto("You kill #{d.name}.")
        $engine.world.db.players_connected(@oid).each {|p|
          $engine.world.add_event(@oid,p.oid,:show,"#{@name} kills #{d.name}.")
        }
        d.disconnect
        # $engine.world.db.delete(d)  Dont delete player, it's annoying
      else
        sendto("You attacks and misses #{d.name}.")
        $engine.world.db.players_connected(@oid).each {|p|
          $engine.world.add_event(@oid,p.oid,:show,"#{@name} attacks and misses #{d.name}.")
        }
      end
    end
  end

end

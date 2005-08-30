#
# file::    cmd_say.rb
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

  # sends <message> to all players in the room
  def cmd_say(*args)
    case args[0]
    when nil
      sendto("What are you trying to say?")
    else
      sendto("You say, \"#{args[0]}\"."+EOL)
      $world.other_players_at_location(@location,@oid).each do |x|
        x.sendto("#{@name} says, \"#{args[0]}\".")
      end
    end
  end

end

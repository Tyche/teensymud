#
# file::    cmd_chat.rb
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

  # sends <message> to all players in the game
  def cmd_chat(args)
    case args
    when nil, ""
      sendto("What are you trying to tell everyone?")
    else
      sendto(Colors[:magenta] + "You chat, \"#{args}\"." + Colors[:reset])
      $engine.world.db.players_connected(@oid).each do |p|
        $engine.world.add_event(@oid,p.oid,:show,
          Colors[:magenta] + "#{@name} chats, \"#{args}\"." + Colors[:reset])
      end
    end
  end

end

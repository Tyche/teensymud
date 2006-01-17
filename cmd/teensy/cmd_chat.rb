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
      sendto("[COLOR=magenta]You chat, \"#{args}\".[/COLOR]")
      $engine.world.players_connected(id).each do |p|
        $engine.world.eventmgr.add_event(id,p.id,:show,
          "[COLOR=magenta]#{name} chats, \"#{args}\".[/COLOR]")
      end
    end
  end

end
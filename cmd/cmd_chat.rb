#
# file::    cmd_chat.rb
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

  # sends <message> to all players in the game
  def cmd_chat(*args)
    case args[0]
    when nil
      sendto("What are you trying to tell everyone?")
    else
      sendto(Colors[:magenta] + "You chat, \"#{$1}\"." + Colors[:reset])
      $world.global_message_others(Colors[:magenta] +
        "#{@name} chats, \"#{$1}\"." + Colors[:reset],@oid)
    end
  end

end

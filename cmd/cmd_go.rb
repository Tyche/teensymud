#
# file::    cmd_go.rb
# author::  Jon A. Lambert
# version:: 2.4.0
# date::    09/12/2005
#
# This source code copyright (C) 2005 by Jon A. Lambert
# All rights reserved.
#
# Released under the terms of the TeensyMUD Public License
# See LICENSE file for additional information.
#
module Cmd

  # sends <message> to all players in the room
  def cmd_go(*args)
    case args[0]
    when nil
      sendto("Where do you want to go?")
    else
      ex = $world.db.get(@location).exits.keys.grep(/^#{args[0]}/)
      if ex.empty?
        sendto("Can't find that place")
      elsif ex.size > 1
        ln = "Which did you mean, "
        ex.each {|x| ln += "\'" + x + "\' "}
        ln += "?"
        sendto(ln)
      else
        $world.add_event(@oid,@location,:leave,ex[0])
      end
    end
  end

end

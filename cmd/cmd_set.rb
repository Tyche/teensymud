#
# file::    cmd_set.rb
# author::  Jon A. Lambert
# version:: 2.4.0
# date::    09/13/2005
#
# This source code copyright (C) 2005 by Jon A. Lambert
# All rights reserved.
#
# Released under the terms of the TeensyMUD Public License
# See LICENSE file for additional information.
#
module Cmd

  # sets the description or timer for an object
  # Syntax:
  #   @set desc #<id> <description>
  #   @set timer #<id> <on|off>
  # (ex. @set desc #1 A beautiful rose.)
  def cmd_set(args)
    case args
    when nil, ""
      sendto("What??")
    when /desc\s+#(\d+)\s+(.*)/
      o = $engine.world.db.get($1.to_i)
      case o
      when nil, 0
        sendto("No object.")
      else
        o.desc = $2
        sendto("Object #" + $1 + " description set.")
      end
    when /timer\s+#(\d+)\s+(on|off)/
      o = $engine.world.db.get($1.to_i)
      case o
      when nil, 0
        sendto("No object.")
      else
        if $2 == 'on'
          o.powered = true
          $engine.world.hamster.register(o)
          sendto("Object #" + $1 + " registered with timer.")
        else
          o.powered = false
          $engine.world.hamster.unregister(o)
          sendto("Object #" + $1 + " unregistered with timer.")
        end
      end
    else
      sendto("What??")
    end
  end

end

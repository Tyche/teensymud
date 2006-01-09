#
# file::    cmd_fart.rb
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

  # adds or deletes a farts trigger to an object
  # Syntax:
  #   @fart add #<id> <progname> <eventtype>
  #   @fart del #<id> <eventtype>
  #   @fart show #<id>
  # (ex. @fart add #1 myprog arrive)
  def cmd_fart(args)
    case args
    when nil, ""
      sendto("What??")
    when /del\s+#(\d+)\s+(\w+)/
      o = $engine.world.db.get($1.to_i)
      case o
      when nil, 0
        sendto("No object.")
      else
        t = o.get_trigger($2)
        if t
          o.delete_trigger($2)
          sendto("Object #" + $1 + " fart trigger deleted.")
        else
          sendto("Trigger #{$2} not found on object.")
        end
      end
    when /add\s+#(\d+)\s+(\w+)\s+(\w+)/
      o = $engine.world.db.get($1.to_i)
      case o
      when nil, 0
        sendto("No object.")
      else
        t = Farts::FartTrigger.new($2,$3)
        o.add_trigger(t)
        sendto("Object #" + $1 + " fart trigger added.")
      end
    when /show\s+#(\d+)/
      o = $engine.world.db.get($1.to_i)
      case o
      when nil, 0
        sendto("No object.")
      else
        sendto("====================TRIGGERS=====================")
        sendto("Program                  Event          Compiled?")
        o.get_triggers.each do |t|
          sendto(sprintf("%-25s %-15s %s", t.fname, t.event.id2name, t.prog ? "yes" : "no"))
        end
      end
    else
      sendto("What??")
    end
  end

end

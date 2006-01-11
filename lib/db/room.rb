#
# file::    room.rb
# author::  Jon A. Lambert
# version:: 2.6.0
# date::    10/12/2005
#
# This source code copyright (C) 2005 by Jon A. Lambert
# All rights reserved.
#
# Released under the terms of the TeensyMUD Public License
# See LICENSE file for additional information.
#

require 'db/gameobject'

# The Room class is the mother of all rooms.
#
class Room < GameObject
  # The hash of exits for this room, where the key is the displayed name
  # of the exit and the value is the room id at the end of the exit.
  property :exits
  logger 'DEBUG'

  # Create a new Room object
  # [+name+]   The displayed name of the room
  # [+return+] A handle to the new Room.
  def initialize(name)
    self.exits={}
    super(name)
  end

  # Event handler
  # [+e+]      The event
  # [+return+] Undefined
  def ass(e)
    case e.kind
    when :describe
      msg = "[COLOR=green](#{id.to_s}) #{name}[/COLOR]\n#{desc}\n"
      $engine.world.eventmgr.add_event(id,e.from,:show,msg)
      fart(e)
    when :describe_exits
      msg = "[COLOR=red]Exits:\n"
      s = exits.size
      if s == 0
        msg << "None.[/COLOR]"
      else
        i = 0
        exits.keys.each do |ex|
          msg << ex
          i += 1
          case s - i
          when 1 then s > 2 ? msg << ", and " : msg << " and "
          when 0 then msg << "."
          else
            msg << ", "
          end
        end
        msg << "[/COLOR]"
      end
      $engine.world.eventmgr.add_event(id,e.from,:show,msg)
      fart(e)
    when :leave
      plyr = $engine.world.db.get(e.from)
      players(e.from).each do |x|
        $engine.world.eventmgr.add_event(id,x.id,:show, plyr.name + " has left #{e.msg}.") if x.session
      end
      # remove player
      delete_contents(plyr.id)
      plyr.location = nil
      $engine.world.eventmgr.add_event(id,exits[e.msg],:arrive,plyr.id)
      fart(e)
    when :arrive
      plyr = $engine.world.db.get(e.msg)
      # add player
      add_contents(plyr.id)
      plyr.location = id
      players(e.msg).each do |x|
        $engine.world.eventmgr.add_event(id,x.id,:show, plyr.name+" has arrived.") if x.session
      end
      plyr.parse('look')
      fart(e)
    else
      super(e)
    end
  end

end


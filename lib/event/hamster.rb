#
# file::    hamster.rb
# author::  Jon A. Lambert
# version:: 2.6.0
# date::    10/28/2005
#
# This source code copyright (C) 2005 by Jon A. Lambert
# All rights reserved.
#
# Released under the terms of the TeensyMUD Public License
# See LICENSE file for additional information.
#

require 'thread'


# The Hamster class is a timer mechanism that issues timing events
#
class Hamster < Thread

  # Constructor for a Hamster.
  # [+time+]      The interval time for events in flaoting point seconds.
  # [+eventtype+] The symbol that defines the kind of event to be issued.
  # [+return+] A reference to the Hamster.
  def initialize(world, time, eventtype)
    @world = world
    @time = time
    @eventtype = eventtype
    @interested = []
    @mutex = Mutex.new
    super {run}
  end

  # Register one's interest in talking to the Hamster.
  # [+obj+]     The interval time for events in flaoting point seconds.
  def register(obj)
    @mutex.synchronize do
      @interested << obj
    end
  end

  # Unregister from the Hamster.
  # [+obj+]     The interval time for events in flaoting point seconds.
  def unregister(obj)
    @mutex.synchronize do
      @interested.delete(obj)
    end
  end

  # The timing thread loop
  def run
    while true
      sleep @time
      @mutex.synchronize do
        @interested.each do |o|
          @world.eventmgr.add_event(nil, o.oid, @eventtype, nil)
        end
      end
    end
  end

end



#
# file::    eventmanager.rb
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

require 'engine/event'

class EventManager

  def initialize
    @tits = []
    @bra = Mutex.new
  end

  # Add an Event to the TITS queue.
  # [+e+]      The event to be added.
  # [+return+] Undefined.
  def add_event(from,to,kind,msg=nil)
    @bra.synchronize do
      @tits.push(Event.new(from,to,kind,msg))
    end
  end

  # Get an Event from the TITS queue.
  # [+return+] The Event or nil
  def get_event
    @bra.synchronize do
      @tits.shift
    end
  end

  def contents
    @tits.inspect
  end

end
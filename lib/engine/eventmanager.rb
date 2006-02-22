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
$:.unshift "lib" if !$:.include? "lib"
$:.unshift "vendor" if !$:.include? "vendor"

require 'engine/event'
require 'utility/log'

class EventManager
  logger 'DEBUG'

  def initialize
    @tits = []
    @bra = Mutex.new
    log.info "Event manager starting..."
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

  # Process events
  # A false return in a PRE trigger will prevent execution of the event
  def process_events
    while e = get_event
      begin
        obj = Engine.instance.db.get(e.to)
        t = obj.get_trigger("pre_"+e.kind.to_s)
        if t
          ret = t.execute(e)
        else
          ret = true
        end
        next if !ret
        obj.send(e.kind,e)
        t = obj.get_trigger(e.kind)
        t.execute(e) if t
      rescue
        log.error "Event failed: #{e}"
        log.error $!
      end
    end
  end
end

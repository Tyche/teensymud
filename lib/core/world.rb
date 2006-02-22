#
# file::    world.rb
# author::  Jon A. Lambert
# version:: 2.8.0
# date::    01/19/2006
#
# This source code copyright (C) 2005, 2006 by Jon A. Lambert
# All rights reserved.
#
# Released under the terms of the TeensyMUD Public License
# See LICENSE file for additional information.
#
$:.unshift "lib" if !$:.include? "lib"
$:.unshift "vendor" if !$:.include? "vendor"

require 'thread'
require 'utility/log'
require 'command'
require 'core/root'
require 'engine/timer'


# The World class is the mother of all worlds.
#
# It contains world state information, the world timer, utility functions,
# and delegates to the Engine.
#
# [+cmds+] is a handle to the player commands table.
# [+ocmds+] is a handle to the object commands table.
# [+timer_list+] is a list of all installed timer objects (persistent)
# [+all_players+] is a list of all players (persistent)
# [+timer_list+] is a list of all connected players
class World < Root
  configuration
  logger 'DEBUG'
  property :timer_list, :all_players
  attr_accessor :cmds, :ocmds, :connected_players

  # Create the World.  This loads or creates the database depending on
  # whether it finds it.
  # [+return+] A handle to the World object.
  def initialize
    self.timer_list = []
    self.all_players = []
    @connected_players = []
  end

  def startup
    @connected_players = []
    @cmds, @ocmds = Command.load
    log.info "Starting Timer..."
    @timer_list_mutex = Mutex.new
    @timer = Thread.new do
      begin
        while true
          sleep 1.0
          @timer_list_mutex.synchronize do
            timer_list.each do |ti|
              if ti.fire?
                add_event(0, ti.id, :timer, ti.name)
                ti.reset
              end
            end
          end
        end
      rescue Exception
        log.fatal "Timer thread blew up"
        log.fatal $!
      end
    end
    log.info "World initialized."
  end

  def shutdown
    connected_players.each{|pid| get_object(pid).disconnect}
    Thread.kill(@timer)
  end

  # Set/add a timer for an object
  # [+id+] The id of the object that wants to get a timer event
  # [+name+] The symbolic name of the timer event
  # [+time+] The interval time in seconds of the timer event
  def set_timer(id, name, time)
    @timer_list_mutex.synchronize do
      timer_list << Timer.new(id, name, time)
    end
  end

  # Unset/remove a timer for an object
  # [+id+] The id of the object to remove a timer event
  # [+name+] The symbolic name of the timer event to remove (or nil for all events)
  def unset_timer(id, name=nil)
    @timer_list_mutex.synchronize do
      if name.nil?
        timer_list.delete_if {|ti| ti.id == id }
      else
        timer_list.delete_if {|ti| ti.id == id && ti.name == name }
      end
    end
  end

  # memstats scans all objects in memory and produces a report
  # [+return+] a string
  def memstats
    # initialize all counters
    rooms = objs = players = strcount = strsize = ocount = 0

    # scan the ObjectSpace counting things
    ObjectSpace.each_object do |x|
      case x
      when String
        strcount += 1
        strsize += x.size
      when Player
        players += 1
      when Room
        rooms += 1
      when GameObject
        objs += 1
      else
        ocount += 1
      end
    end

    # our report  :
    # :NOTE: sprintf would be better
    memstats=<<EOD
[COLOR=cyan]
----* Memory Statistics *----
  Rooms   - #{rooms}
  Players - #{players}
  Objects - #{objs}
-----------------------------
  Strings - #{strcount}
     size - #{strsize} bytes
  Other   - #{ocount}
-----------------------------
  Total Objects - #{rooms+objs+players+strcount+ocount}
----*                   *----
[/COLOR]
EOD
  end

end

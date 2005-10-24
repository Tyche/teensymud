#
# file::    gameobject.rb
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

# The GameObject class is the mother of all objects.
#
class GameObject
  # The unique database id of the object
  attr_accessor :oid
  # The displayed name of the object
  attr_accessor :name
  # The object that holds this object or nil if none
  attr_accessor :location
  # The displayed description of the object
  attr_accessor :desc
  # Flag indicating whether this object is interested in timer events
  attr_accessor :powered

  # Create a new Object
  # [+name+]     Every object needs a name
  # [+location+] The object oid containing this object or nil.
  # [+return+]   A handle to the new Object
  def initialize(name,location=nil)
    @name,@location,@oid=name,location,$engine.world.db.getid
    @contents = []
    @farts = {}
    @desc = ""
    @powered = false
    $engine.world.db.get(@location).add_contents(@oid) if @location
  end

  # Add an object to the contents of this object
  # [+oid+] The object id to add
  def add_contents(oid)
    @contents << oid
  end

  # Deletes an object from the contents of this object
  # [+oid+] The object id to delete
  def delete_contents(oid)
    @contents.delete(oid)
  end

  # Returns the contents of the object
  # [+return+] An array of object ids
  def get_contents
    @contents
  end

  # Add a trigger to this object
  # [+t+] The trigger to add
  def add_trigger(t)
    @farts[t.event] = t
  end

  # Deletes a trigger from this object
  # [+event+] The trigger event type to delete
  def delete_trigger(event)
    event = event.intern if event.respond_to?(:to_str)
    @farts.delete(event)
  end

  # Returns a specific trigger from the object
  # [+event+] The trigger event type to retrieve
  # [+return+] A trigger or nil
  def get_trigger(event)
    event = event.intern if event.respond_to?(:to_str)
    @farts[event]
  end

  # Returns the triggers on the object
  # [+return+] An array of triggers
  def get_triggers
    @farts.values
  end

  # Fart handler
  # [+e+]      The event
  # [+return+] true or false
  def fart(ev)
    t = get_trigger(ev.kind)
    if t
      t.execute(ev)
    else
      true
    end
  end

  # Finds all objects contained in this object
  # [+return+] Handle to a array of the objects.
  def objects
    ary = @contents.collect do |oid|
      o = $engine.world.db.get(oid)
      o.class == GameObject ? o : nil
    end
    ary.compact
  end

  # Finds all the players contained in this object except the passed player.
  # [+exempt+]  The player oid exempted from the list.
  # [+return+] Handle to a list of the Player objects.
  def players(exempt=nil)
    ary = @contents.collect do |oid|
      o = $engine.world.db.get(oid)
      (o.class == Player && oid != exempt && o.session) ? o : nil
    end
    ary.compact
  end

  # All command input routed through here and parsed.
  # [+m+]      The input message to be parsed
  # [+return+] false or true depending on whether command succeeded.
  def parse(m)
    # match legal command
    m=~/([A-Za-z0-9_@?"'#!]+)(.*)/
    cmd=$1
    arg=$2
    arg.strip! if arg

    # look for a command from our table for objects
    c = $engine.world.ocmds.find(cmd)

    # there are three possibilities here
    case c.size
    when 0   # no commands found
      false
    when 1   # command found
      return self.send(c[0].cmd, arg)
    else     # ambiguous command - tell luser about them.
      false
    end
  end

  # Event handler
  # [+e+]      The event
  # [+return+] Undefined
  def ass(e)
    case e.kind
    when :describe
      msg = "[COLOR=yellow]A #{name} is here[/COLOR]"
      $engine.world.add_event(@oid,e.from,:show,msg)
      fart(e)
    when :get
      plyr = $engine.world.db.get(e.from)
      place = $engine.world.db.get(@location)
      # remove it
      place.delete_contents(@oid)
      # add it
      plyr.add_contents(@oid)
      @location = plyr.oid
      $engine.world.add_event(@oid,e.from,:show,"You get the #{@name}")
      fart(e)
    when :drop
      plyr = $engine.world.db.get(e.from)
      place = $engine.world.db.get(plyr.location)
      # remove it
      plyr.delete_contents(@oid)
      # add it
      place.add_contents(@oid)
      @location = place.oid
      $engine.world.add_event(@oid,e.from,:show,"You drop the #{@name}")
      fart(e)
    when :timer
      fart(e)
    end
  end
end


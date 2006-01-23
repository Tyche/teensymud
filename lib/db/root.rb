#
# file::    root.rb
# author::  Jon A. Lambert
# version:: 2.7.0
# date::    01/13/2006
#
# This source code copyright (C) 2005 by Jon A. Lambert
# All rights reserved.
#
# Released under the terms of the TeensyMUD Public License
# See LICENSE file for additional information.
#
require 'log'
require 'db/properties'
require 'farts/farts_parser'

# The Root class is the mother of all objects.
#
class Root
  configuration
  property :name, :owner, :desc
  logger 'DEBUG'

  # Create a new Root
  # [+name+]     Every object needs a name
  # [+owner+]    The owner id of this object
  # [+return+]   A handle to the new Object
  def initialize(name, owner)
    self.id                     # The database id of the object
    self.name = name            # The displayed name of the object
    self.owner = owner || id    # The owner of the object or itself.
    self.desc = ""              # The description of the object
  end

  # Clone an object
  # This does a deepcopy then assign a new database id
  #
  # [+return+]   A handle to the new Object
  def clone
    newobj = Marshal.load(Marshal.dump(self))
    props = newobj.instance_variable_get(:@props)
    props[:id] = Engine.instance.db.getid
    put_object(newobj)
    newobj
  rescue
    log.error "Clone failed"
    nil
  end

  # All command input routed through here and parsed.
  # [+m+]      The input message to be parsed
  # [+return+] false or true depending on whether command succeeded.
  def parse(m)
    false
  end

  # Event handler
  # [+e+]      The event
  # [+return+] Undefined
  def ass(e)
  end

  def world
    Engine.instance.db.get(0)
  end

  def add_event(from,to,kind,msg=nil)
    Engine.instance.eventmgr.add_event(from,to,kind,msg)
  end

  def get_object(oid)
    Engine.instance.db.get(oid)
  end

  def put_object(obj)
    Engine.instance.db.put(obj)
  end

  def delete_object(oid)
    Engine.instance.db.delete(oid)
  end
end


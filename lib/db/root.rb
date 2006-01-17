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
    props[:id] = $engine.world.db.getid
    $engine.world.db.put(newobj)
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
end


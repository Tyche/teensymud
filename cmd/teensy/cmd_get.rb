#
# file::    cmd_get.rb
# author::  Jon A. Lambert, Chris Bailey
# version:: 3.0.0
# date::    02/20/2013
#
# This source code copyright (C) 2005-2013 by Jon A. Lambert
# All rights reserved.
#
# Released under the terms of the TeensyMUD Public License
# See LICENSE file for additional information.
#
module Cmd

  # gets a specific object from the room you are in.
  def cmd_get(args)
    if args == "all"
      get_object(location).objects.each do |q|
        add_event(id,q.id,:get)
      end
      return
    end
    found_object = false
    get_object(location).objects.each do |obj|
      if (obj.name.is_match?(args) || args.is_prefix?(obj.name))
        found_object = true
        add_event(id,obj.id,:get)
        break
      end
    end
    
    if !found_object
      sendto "You cannot find that object."
    end
  end

end

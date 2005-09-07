#
# file::    cmd_get.rb
# author::  Jon A. Lambert
# version:: 2.2.0
# date::    08/29/2005
#
# This source code copyright (C) 2005 by Jon A. Lambert
# All rights reserved.
#
# Released under the terms of the TeensyMUD Public License
# See LICENSE file for additional information.
#
module Cmd

  # gets all objects in the room into your inventory
  def cmd_get(*args)
    $world.db.get(@location).objects.each do |q|
      $world.add_event(@oid,q.oid,:get)
    end
  end

end

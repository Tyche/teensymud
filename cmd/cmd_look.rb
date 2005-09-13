#
# file::    cmd_look.rb
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

  # Look command displays the contents of a room
  def cmd_look(args)
    place = $world.db.get(@location)
    $world.add_event(@oid,@location,:describe)
    place.objects.each do |x|
      $world.add_event(@oid,x.oid,:describe)
    end
    place.players(@oid).each do |x|
      $world.add_event(@oid,x.oid,:describe)
    end
    $world.add_event(@oid,@location,:describe_exits)
  end

end

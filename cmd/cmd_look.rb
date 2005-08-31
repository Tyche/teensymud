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
  def cmd_look(*args)
    $world.add_event(@oid,@location,:describe)
    $world.objects_at_location(@location).each do |x|
      $world.add_event(@oid,x.oid,:describe)
    end
    $world.other_players_at_location(@location,@oid).each do |x|
      $world.add_event(@oid,x.oid,:describe) if x.session
    end
    $world.add_event(@oid,@location,:describe_exits)
  end

end

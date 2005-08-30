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
    sendto(Colors[:green] + "(" + @location.to_s + ") " +
      $world.find_by_oid(@location).name + Colors[:reset] + EOL +
      $world.find_by_oid(@location).desc + EOL)
    $world.other_players_at_location(@location,@oid).each do |x|
      sendto(Colors[:blue] + x.name + " is here." + Colors[:reset]) if x.session
    end
    $world.objects_at_location(@location).each do |x|
      sendto(Colors[:yellow] + "A " + x.name + " is here" + Colors[:reset])
    end
    sendto(Colors[:red] + "Exits: " +
      $world.find_by_oid(@location).exits.keys.join(' | ') + Colors[:reset])
  end

end

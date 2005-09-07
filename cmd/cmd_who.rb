#
# file::    cmd_who.rb
# author::  Jon A. Lambert
# version:: 2.3.0
# date::    08/31/2005
#
# This source code copyright (C) 2005 by Jon A. Lambert
# All rights reserved.
#
# Released under the terms of the TeensyMUD Public License
# See LICENSE file for additional information.
#
module Cmd

  # The inventory command
  def cmd_who(*args)
    $world.db.players_connected.each {|p| sendto(p.name)}
  end

end

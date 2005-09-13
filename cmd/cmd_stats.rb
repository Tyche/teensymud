#
# file::    cmd_stats.rb
# author::  Jon A. Lambert
# version:: 2.4.0
# date::    09/07/2005
#
# This source code copyright (C) 2005 by Jon A. Lambert
# All rights reserved.
#
# Released under the terms of the TeensyMUD Public License
# See LICENSE file for additional information.
#
module Cmd

  # The inventory command
  def cmd_stats(args)
    sendto($world.db.stats)
  end

end

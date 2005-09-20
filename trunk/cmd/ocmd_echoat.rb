#
# file::    ocmd_echoat.rb
# author::  Jon A. Lambert
# version:: 2.4.0
# date::    09/12/2005
#
# This source code copyright (C) 2005 by Jon A. Lambert
# All rights reserved.
#
# Released under the terms of the TeensyMUD Public License
# See LICENSE file for additional information.
#
module ObjCmd

  # This command echos input to location
  def ocmd_echoat(args)
    case args
    when nil, ""
      false
    when /(\d+) (.*)/
      $engine.world.db.get($1.to_i).players(@oid).each do |p|
        $engine.world.add_event(@oid,p.oid,:show,$2)
      end
      true
    else
      false
    end
  end

end

#
# file::    timer.rb
# author::  Jon A. Lambert
# version:: 2.8.0
# date::    01/19/2006
#
# This source code copyright (C) 2005, 2006 by Jon A. Lambert
# All rights reserved.
#
# Released under the terms of the TeensyMUD Public License
# See LICENSE file for additional information.
#

# The Timer class defines the necessary data to keep track of timers for
# objects
#
class Timer
  attr_accessor :id, :name, :time

  # Constructor for a Timer object.
  # [+id+]     The id of the object
  # [+name+]   The symbol that defines the kind of timer event.
  # [+time+]   Optional information needed to process the event.
  # [+return+] A reference to the Timer.
  def initialize(id,name,time)
    @id,@name,@time,@counter=id,name,time,time
  end

  def fire?
    @counter -= 1
    @counter < 1
  end

  def reset
    @counter = @time
  end

end



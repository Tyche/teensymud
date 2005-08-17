#
# file::    tmud.rb
# author::  Jon A. Lambert
# version:: 2.0.0
# date::    08/15/2005
# 
# This source code copyright (C) 2005 by Jon A. Lambert
# All rights reserved.
#
# Released under the terms of the Mesh Public License
# See LICENSE file for additional information.
#
require 'socket'
require 'yaml'

Version = "2.0.0"

# Telnet end of line 
EOL="\r\n"

# Displayed upon connecting
BANNER=<<-EOH.gsub!(/\n/,EOL)


            This is TeensyMUD version #{Version}
               
          Copyright (C) 2005 by Jon A. Lambert
 Released under the terms of the TeensyMUD Public License


Login>
EOH

# Displayed when help requested
HELP=<<-EOH.gsub!(/\n/,EOL)
===========================================================================
Play commands
  i[nventory] = displays player inventory
  l[ook] = displays the contents of a room
  dr[op] = drops all objects in your inventory into the room
  g[get] = gets all objects in the room into your inventory
  k[ill] <name> = attempts to kill player (e.g. k bubba)
  s[ay] <message> = sends <message> to all players in the room
  c[hat] <message> = sends <message> to all players in the game
  h[elp]|?  = displays help
  q[uit]    = quits the game (saves player)
  <exit name> = moves player through exit named (ex. south)
===========================================================================
OLC
  O <object name> = creates a new object (ex. O rose)
  R <room name> <exit name to> <exit name back> = creates a new room and 
    autolinks the exits using the exit names provided.
===========================================================================
EOH

# The Obj class is the mother of all objects.
#
class Obj
  # The unique database id of the object 
  attr_accessor :oid
  # The displayed name of the object
  attr_accessor :name   
  # The object that holds this object or nil if none
  attr_accessor :location

  # Create a new Object
  # [+name+]     Every object needs a name
  # [+location+] The object oid containing this object or nil.
  # [+return+]   A handle to the new Object
  def initialize(name,location)
    @name,@location,@oid=name,location,$world.getid
  end
end

# The Room class.is the mother of all rooms.
#
class Room < Obj
  # The hash of exits for this room, where the key is the displayed name 
  # of the exit and the value is the room oid at the end of the exit.
  attr_accessor :exits

  # Create a new Room object
  # [+name+]   The displayed name of the room
  # [+return+] A handle to the new Room.
  def initialize(name)
    @exits={}
    super(name,location)
  end
end

# The Player class is the mother of all players.
# Who's their daddy?
#
class Player < Obj
  # The socket object this player is connected on or nil if not.
  attr_accessor :sock

  # Create a new Player object
  # [+name+]   The displayed name of the player.
  # [+sock+]   The socket object this player is connected on or nil if not.
  # [+return+] A handle to the new Player.
  def initialize(name,sock)
    @sock=sock
    super(name,1)
  end

  # Sends a message to the player if they are connected.
  # [+s+]      The message string
  # [+return+] Undefined.
  def sendto(s)
    @sock.write(s+EOL) if @sock
  end

  # All input routed through here and parsed. 
  # [+m+]      The input message to be parsed
  # [+return+] Undefined.
  def parse(m)
    m=~/(\w+)\W(.*)/
    cmd=$1
    arg=$2
    case m
    when /^q/
      @sock.close
      @sock=nil
      $world.save
    when /^h|\?/
      sendto(HELP)
    when /^i.*/
      $world.objects_at_location(@oid).each{|o|sendto(o.name)}
    when /^k.* (.*)/
      d=$world.find_player_by_name($1)
      if d && rand<0.3
        $world.global_message(@name+" kills "+d.name)
        d.sock.close
        $world.delete(d)
        $world.save
      else
        $world.global_message(@name+" misses")
      end
    # say - only to room 
    when /^s.* (.*)/
      sendto("You say, \"#{$1}\"."+EOL)
      $world.other_players_at_location(@location,@oid).each do |x|
        x.sendto("#{@name} says, \"#{$1}\".")
      end
    when /^c.* (.*)/
      sendto("You chat, \"#{$1}\".")
      $world.global_message_others("#{@name} chats, \"#{$1}\".",@oid)
    when /^g.*/
      $world.objects_at_location(@location).each do |q|
        q.location=@oid
      end  
      sendto("Ok."+EOL)
    when /^dr.*/
      $world.objects_at_location(@oid).each do |q|
        q.location=@location
      end
      sendto("Ok."+EOL)
    when /^O (.*)/
      $world.add(Obj.new($1,@location))
      sendto("Ok."+EOL)
      $world.save
    when /^R (.*) (.*) (.*)/
      d=Room.new($1)
      $world.add(d)
      $world.find_by_oid(@location).exits[$2]=d.oid
      d.exits[$3]=$world.find_by_oid(@location).oid
      sendto("Ok."+EOL)
      $world.save
    # look
    when /^l.*/
      sendto("Room: "+$world.find_by_oid(@location).name+EOL)
      sendto("Players:"+EOL)
      $world.other_players_at_location(@location,@oid).each do |x|
        sendto(x.name+" is here.") if x.sock
      end
      sendto("Objects:"+EOL)
      $world.objects_at_location(@location).each{|x|sendto("A "+x.name+" is here")}
      sendto("Exits: "+$world.find_by_oid(@location).exits.keys.join(' | '))
    # for the last check create a list of exit names to scan.
    when /(^#{$world.find_by_oid(@location).exits.empty? ? "\1" : $world.find_by_oid(@location).exits.keys.join('|^')})/
      @location=$world.find_by_oid(@location).exits[$1]
      parse('look')
    else
      sendto("Huh?")
    end
  end
end


# The World class.is the mother of all worlds. 
#
# It contains the database and all manner of utility functions. It's a 
# big global thing.
#
# [+db+] is a handle to the database which is a simple list of all objects.
# [+dbtop+] 
class World

# The minimal database will be used in the absence of detecting one.
MINIMAL_DB=<<EOH
--- 
- !ruby/object:Room 
  exits: {}
  location: 
  name: Home
  oid: 1
EOH

  # Create the World.  This loads or creates the database depending on
  # whether it finds it.
  # [+return+] A handle to the World object.
  def initialize
    if !test(?e,'db/world.yaml')
      $stdout.puts "Building minimal world database..."
      File.open('db/world.yaml','w') do |f|
        f.write(MINIMAL_DB)
      end
      $stdout.puts "Done."
    end  
    $stdout.puts "Loading world..."
    @db=YAML::load(File.open('db/world.yaml'))
    @dbtop=@db.size
    $stdout.puts "Done."
  end

  # Fetch the next available oid.
  # [+return+] An oid.
  def getid
    @dbtop+=1
  end
  
  # Save the world
  # [+return+] Undefined.
  def save
    File.open('db/world.yaml','w'){|f|YAML::dump(@db,f)}
  end
  
  # Adds a new object to the database.
  # [+obj+] is a reference to object to be added
  # [+return+] Undefined.
  def add(obj)
    @db<<obj
  end

  # Deletes an object from the database.
  # [+obj+] is a reference to object to be deleted.
  # [+return+] Undefined.
  def delete(obj)
    @db.delete(obj)
  end

  # Finds an object in the database by oid.
  # [+i+] is the oid to use in the search.
  # [+return+] Handle to the object or nil.
  def find_by_oid(i)
    @db.find{|o|i==o.oid}
  end
  
  # Finds a Player object in the database by name.
  # [+nm+] is the string to use in the search.
  # [+return+] Handle to the Player object or nil.
  def find_player_by_name(nm)
    @db.find{|o|Player==o.class&&nm==o.name}
  end

  # Finds all the players at a location.
  # [+loc+]    The location oid searched or nil for everywhere.
  # [+return+] Handle to a list of the Player objects.
  def players_at_location(loc)
    @db.find_all{|o|(o.class==Player)&&(!loc||loc==o.location)}
  end

  # Finds all the players at a location except the passed player.
  # [+loc+]    The location oid searched or nil for everywhere.
  # [+plrid+]  The player oid excepted from the list.
  # [+return+] Handle to a list of the Player objects.
  def other_players_at_location(loc,plrid)
    @db.find_all{|o|(o.class==Player)&&(!loc||loc==o.location)&&o.oid!=plrid}
  end

  # Sends a message to all players in the world.
  # [+msg+]    The message text to send
  # [+return+] Undefined.
  def global_message(msg)
    players_at_location(nil).each{|plr|plr.sendto(msg)}
  end

  # Sends a message to all players in the world except the passed player.
  # [+msg+]    The message text to send
  # [+plrid+]  The player oid excepted from the list.
  # [+return+] Undefined.
  def global_message_others(msg,plrid)
    other_players_at_location(nil,plrid).each{|plr|plr.sendto(msg)}
  end

  # Finds all Objects at a location
  # [+loc+]    The location oid searched or nil for everywhere.
  # [+return+] Handle to a list of the Obj objects.
  def objects_at_location(loc)
    @db.find_all{|o|(o.class==Obj)&&(!loc||loc==o.location)}
  end
end

###########################################################################
# This is start of the network code.
###########################################################################

# Setup traps
begin
Signal.trap("INT") do
  $stdout.puts "Interrupt control request to shutdown."
  $stdout.puts "Saving world..."
  $world.save
  exit
end
Signal.trap("TERM") do
  $stdout.puts "Termination request to shutdown."
  $stdout.puts "Saving world..."
  $world.save
  exit
end
Signal.trap("KILL") do 
  $stdout.puts "Kill request to shutdown."
  $stdout.puts "Saving world..."
  $world.save
  exit
end

# Create the $world a global object containing everything.
$world=World.new
$stdout.puts "Booting server on port 4000"
server=TCPServer.new(0,4000)
$stdout.puts "TMUD is ready"

# Server accept loop. 
# It blocks on accept and spawns a thread everytime someone connects.
while sk=server.accept
  Thread.new(sk) do |sock|
    begin
      sock.write(BANNER)
      sock.gets
      login_name=$_.chomp
      d=$world.find_player_by_name(login_name)
      # needs a state machine
      if d
        d.sock=sock
      else
        d=Player.new(login_name,sock)
        $world.add(d)
      end
      d.sendto("Welcome " + d.name + "@" + sock.peeraddr[2] + "!")
      d.parse('look')
      while sock.gets
        d.parse($_.chomp)
      end
    rescue => e  # Override
      $stdout.puts "Caught error in client thread: #{e}"
    end
  end
end
rescue => e
  $stdout.puts "Caught error in server thread: #{e}"
  exit
end


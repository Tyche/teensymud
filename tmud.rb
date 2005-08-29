#
# file::    tmud.rb
# author::  Jon A. Lambert
# version:: 2.1.0
# date::    08/23/2005
#
# This source code copyright (C) 2005 by Jon A. Lambert
# All rights reserved.
#
# Released under the terms of the TeensyMUD Public License
# See LICENSE file for additional information.
#
require 'net'
require 'observer'
require 'yaml'

Version = "2.1.0"

# Telnet end of line
EOL="\r\n"

# Displayed upon connecting
BANNER=<<-EOH.gsub!(/\n/,EOL)


            This is TeensyMUD version #{Version}

          Copyright (C) 2005 by Jon A. Lambert
 Released under the terms of the TeensyMUD Public License


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
  S #<objectid> <description> = sets the description for an object
===========================================================================
EOH

Colors = {:black => "\e[30m", :red => "\e[31m", :green => "\e[32m",
  :yellow => "\e[33m", :blue => "\e[34m", :magenta => "\e[35m",
  :cyan => "\e[36m", :white => "\e[37m", :reset => "\e[0m"}

# The Obj class is the mother of all objects.
#
class Obj
  # The unique database id of the object
  attr_accessor :oid
  # The displayed name of the object
  attr_accessor :name
  # The object that holds this object or nil if none
  attr_accessor :location
  # The displayed description of the object
  attr_accessor :desc

  # Create a new Object
  # [+name+]     Every object needs a name
  # [+location+] The object oid containing this object or nil.
  # [+return+]   A handle to the new Object
  def initialize(name,location)
    @name,@location,@oid=name,location,$world.getid
    @desc = ""
  end
end

# The Room class is the mother of all rooms.
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
  include Observable

  # The session object this player is connected on or nil if not.
  attr_accessor :session

  # Create a new Player object
  # [+name+]    The displayed name of the player.
  # [+passwd+]  The player password in clear text.
  # [+session+] The session object this player is connected on or nil if not.
  # [+return+]  A handle to the new Player.
  def initialize(name,passwd,session)
    @session = session
    @passwd = encrypt(passwd)
    super(name,1)
  end

  # Sends a message to the player if they are connected.
  # [+s+]      The message string
  # [+return+] Undefined.
  def sendto(s)
    sendmsg(s+EOL) if @session
  end

  # Helper method to notify all observers
  # [+msg+]      The message string
  def sendmsg(msg)
    changed
    notify_observers(msg)
  end

  # Receives messages from connection and passes text ones on to parse.
  # [+msg+]      The message string
  def update(msg)
    case msg
    when :logged_out
      @session = nil
      delete_observers
      $world.global_message_others("#{@name} has quit.",@oid)
    when :disconnected
      @session = nil
      delete_observers
      $world.global_message_others("#{@name} has disconnected.",@oid)
    else
      parse(msg)
    end
  end

private
  # Encrypts a password
  # [+passwd+] The string to be encrypted
  # [+return+] The encrypted string
  def encrypt(passwd)
    alphabet = 'abcdefghijklmnopqrstuvwxyzABCDEFGHIJKLMNOPQRSTUVWXYZ0123456789./'
    salt = "#{alphabet[rand(64)].chr}#{alphabet[rand(64)].chr}"
    passwd.crypt(salt)
  end

public
  # Compares the password with the players
  # [+p+] The string passed as password in clear text
  # [+return+] true if they are equal, false if not
  def check_passwd(p)
    @passwd == p.crypt(@passwd)
  end

  # Disconnects this player
  def disconnect
    sendmsg(:logged_out)
    delete_observers
    @session = nil
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
      disconnect
    when /^h|\?/
      sendto(HELP)
    when /^i.*/
      $world.objects_at_location(@oid).each{|o|sendto(o.name)}
    when /^k.* (.*)/
      d=$world.find_player_by_name($1)
      if d && rand<0.3
        $world.global_message(@name+" kills "+ d.name)
        d.disconnect
        $world.delete(d)
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
      sendto(Colors[:magenta] + "You chat, \"#{$1}\"." + Colors[:reset])
      $world.global_message_others(Colors[:magenta] +
        "#{@name} chats, \"#{$1}\"." + Colors[:reset],@oid)
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
    when /^R (.*) (.*) (.*)/
      d=Room.new($1)
      $world.add(d)
      $world.find_by_oid(@location).exits[$2]=d.oid
      d.exits[$3]=$world.find_by_oid(@location).oid
      sendto("Ok." + EOL)
    when /^S #(\d+) (.*)/
      r = $world.find_by_oid($1.to_i)
      case r
      when nil, 0
        sendto("No object."+EOL)
      else
        r.desc = $2
        sendto("Object #" + $1 + " description set." + EOL)
      end
    # look
    when /^l.*/
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
    # for the last check create a list of exit names to scan.
    when /(^#{$world.find_by_oid(@location).exits.empty? ? "\1" : $world.find_by_oid(@location).exits.keys.join('|^')})/
      $world.other_players_at_location(@location,@oid).each do |x|
        x.sendto(@name+" has left #{$1}.") if x.session
      end
      @location=$world.find_by_oid(@location).exits[$1]
      $world.other_players_at_location(@location,@oid).each do |x|
        x.sendto(@name+" has arrived from #{$1}.") if x.session
      end
      parse('look')
    else
      sendto("Huh?")
    end
  end
end


# The World class is the mother of all worlds.
#
# It contains the database and all manner of utility functions. It's a
# big global thing.
#
# [+db+] is a handle to the database which is a simple list of all objects.
# [+dbtop+] stores the highest oid used in the database.
class World

# The minimal database will be used in the absence of detecting one.
MINIMAL_DB=<<EOH
---
- !ruby/object:Room
  exits: {}
  location:
  desc: "This is home."
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
    @dbtop = 0
    @db = YAML::load_file('db/world.yaml')
    @db.each {|o| @dbtop = o.oid if o.oid > @dbtop}
    $stdout.puts "Loaded...dbtop=#{@dbtop}."
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


# The Incoming class handles connection login and passes them to
# player.
class Incoming
  include Observable

  # Create an incoming connection.  This is a temporary object that handles
  # login for player and gets them connected.
  # [+conn+]   The session associated with this incoming connection.
  # [+return+] A handle to the incoming object.
  def initialize(conn)
    @conn = conn
    @state = :name
    @checked = 0
    @player = nil
  end

  # Receives messages from connection and handles login state.  On
  # successful login the observer status will be transferred to the
  # player object.
  # [+msg+]      The message string
  def update(msg)
    case msg
    when :logged_out, :disconnected
      delete_observers
    else
      if (@checked += 1) > 3
        sendmsg("Bye!")
        sendmsg(:logged_out)
        delete_observers
      end
      case @state
      when :name
        @login_name = msg
        @player = $world.find_player_by_name(@login_name)
        sendmsg("password> ")
        @state = :password
      when :password
        @login_passwd = msg
        if @player
          if @player.check_passwd(@login_passwd)  # good login
            @player.session = @conn
            login
          else  # bad login
            sendmsg("Sorry wrong password" + EOL)
            @state = :name
            sendmsg("login> ")
          end
        else  # new player
          @player = Player.new(@login_name,@login_passwd,@conn)
          $world.add(@player)
          login
        end
      end
    end
  end

  def sendmsg(msg)
    changed
    notify_observers(msg)
  end

private
  # Called on successful login
  def login
    # deregister all observers here and on connection
    delete_observers
    @conn.delete_observers

    # reregister all observers to @player
    @conn.add_observer(@player)
    @player.add_observer(@conn)

    @player.sendto("Welcome " + @login_name + "@" + @conn.sock.peeraddr[2] + "!")
    $world.global_message_others("#{@player.name} has connected.",@player.oid)
    @player.parse('look')
  end

end


# The Engine class sets up the server, polls it regularly and observes
# acceptor for incoming connections.
class Engine
  attr_accessor :shutdown

  # Create the an engine.
  # [+port+]   The port passed to create a reactor.
  # [+return+] A handle to the engine.
  def initialize(port)
    $stdout.puts "Booting server on port #{port}"
    @server = Reactor.new(port)
    @incoming = []
    @shutdown = false
  end

  # main loop to run engine.
  # note:: @shutdown never set by anyone yet
  def run
    @server.start(self)
    $stdout.puts "TMUD is ready"
    until @shutdown
      @server.poll(0.2)
    end # until
    @server.stop
  end

  # Update is called by an acceptor passing us a new session.  We create
  # an incoming object and set it and the connection to watch each other.
  def update(newconn)
    inc = Incoming.new(newconn)
    # Observe each other
    newconn.add_observer(inc)
    inc.add_observer(newconn)
    inc.sendmsg(BANNER)
    inc.sendmsg("login> ")
  end
end


###########################################################################
# This is start of the main driver.
###########################################################################

# Setup traps - invoke one of these signals to shut down the mud
def handle_signal(sig)
  $stdout.puts "Signal caught request to shutdown."
  $stdout.puts "Saving world..."
  $world.players_at_location(nil).each{|plr|plr.disconnect if plr.session}
  $world.save
  exit
end

Signal.trap("INT", method(:handle_signal))
Signal.trap("TERM", method(:handle_signal))
Signal.trap("KILL", method(:handle_signal))

begin
  # Create the $world a global object containing everything.
  $world=World.new

  $engine = Engine.new(4000)
  $engine.run
rescue => e
  $stderr.puts "Exception caught error in server: " + $!
  $stderr.puts $@
  exit
end


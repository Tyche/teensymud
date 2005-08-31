#
# file::    tmud.rb
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
require 'observer'
require 'yaml'

$:.unshift "lib"
require 'net'
require 'command'

Version = "2.2.0"

# Telnet end of line
EOL="\r\n"

# Displayed upon connecting
BANNER=<<-EOH.gsub!(/\n/,EOL)


            This is TeensyMUD version #{Version}

          Copyright (C) 2005 by Jon A. Lambert
 Released under the terms of the TeensyMUD Public License


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

  def ass(e)
    case e.kind
    when :describe
      msg = Colors[:yellow] + "A " + @name + " is here" + Colors[:reset]
      $world.add_event(@oid,e.from,:show,msg)
    when :get
      plyr = $world.find_by_oid(e.from)
      @location=plyr.oid
      $world.add_event(@oid,e.from,:show,"You get the #{@name}")
    when :drop
      plyr = $world.find_by_oid(e.from)
      @location=plyr.location
      $world.add_event(@oid,e.from,:show,"You drop the #{@name}")
    end
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

  def ass(e)
    case e.kind
    when :describe
      msg = Colors[:green] + "(" + @oid.to_s + ") " + name +
        Colors[:reset] + EOL + desc + EOL
      $world.add_event(@oid,e.from,:show,msg)
    when :describe_exits
      msg = Colors[:red] + "Exits: " + @exits.keys.join(' | ') + Colors[:reset]
      $world.add_event(@oid,e.from,:show,msg)
    when :leave
      plyr = $world.find_by_oid(e.from)
      $world.other_players_at_location(@oid,e.from).each do |x|
        $world.add_event(@oid,x.oid,:show, plyr.name + " has left #{e.msg}.") if x.session
      end
      plyr.location = @exits[e.msg]
      $world.add_event(@oid,@exits[e.msg],:arrive,plyr.oid)
    when :arrive
      plyr = $world.find_by_oid(e.msg)
      $world.other_players_at_location(@oid,e.msg).each do |x|
        $world.add_event(@oid,x.oid,:show, plyr.name+" has arrived.") if x.session
      end
      plyr.parse('look')
    else
      super(e)
    end
  end

end

# The Player class is the mother of all players.
# Who's their daddy?
#
class Player < Obj
  include Observable

  # The Session object this player is connected on or nil if not connected.
  attr_accessor :session

  # Create a new Player object
  # [+name+]    The displayed name of the player.
  # [+passwd+]  The player password in clear text.
  # [+session+] The session object this player is connecting on.
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
      $world.players_connected(@oid).each {|p|
        $world.add_event(@oid,p.oid,:show,"#{@name} has quit.")
      }
    when :disconnected
      @session = nil
      delete_observers
      $world.players_connected(@oid).each {|p|
        $world.add_event(@oid,p.oid,:show,"#{@name} has disconnected.")
      }
    else
      parse(msg)
    end
  end

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
    # match legal command
    m=~/([A-Za-z@?"'#!]+)(.*)/
    cmd=$1

    # cmds take an array - we ought to parse this into an array of strings
    # instead of sending an array of one string or nil
    arg = $2.strip if $2
    arg = nil if arg.nil? || arg.empty?

    # look for a command in our spanking new table
    c = $world.cmds.find(cmd)
    # there are three possibilities here
    if c && c.size > 1   # Ambiguous command - tell luser about them.
      ln = "Which did you mean, "
      c.each {|x| ln += "\'" + x.name + "\' "}
      ln += "?"
      sendto(ln)
      return
    elsif c && c.size == 1  # We found it
      self.send(c[0].cmd, arg)
      return
    else
      case m
      # for the last check create a list of exit names to scan.
      when /(^#{$world.find_by_oid(@location).exits.empty? ? "\1" : $world.find_by_oid(@location).exits.keys.join('|^')})/
        $world.add_event(@oid,@location,:leave,$1)
      else
        sendto("Huh?")
      end
    end
  end

  def ass(e)
    case e.kind
    when :describe
      msg = Colors[:cyan] + @name + " is here." + Colors[:reset]
      $world.add_event(@oid,e.from,:show,msg)
    when :show
      sendto(e.msg)
    else
      super(e)
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

end

# The Event class is a temporally immediate message that is to be propagated
# to another object.
class Event
  attr_accessor :from, :to, :kind, :msg

  # Constructor for an Event.
  # [+from+]   The oid of the issuer of the event.
  # [+to+]     The oid of the target of the event.
  # [+kind+]   The symbol that defines the kind of event.
  # [+msg+]    Optional information needed to process the event.
  # [+return+] A reference to the Event.
  def initialize(from,to,kind,msg=nil)
    @from,@to,@kind,@msg=from,to,kind,msg
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

  attr_accessor :cmds, :tits
  attr_reader :options


  # Create the World.  This loads or creates the database depending on
  # whether it finds it.
  # [+return+] A handle to the World object.
  def initialize(options)
    @options=options
    if !test(?e,'db/world.yaml')
      $stdout.puts "Building minimal world database..."
      File.open('db/world.yaml','w') do |f|
        f.write(MINIMAL_DB)
      end
      $stdout.puts "Done."
    end
    $stdout.puts "Loading world..."
    @dbtop = 0
    @db = {}
    tmp = YAML::load_file('db/world.yaml')
    tmp.each do |o|
      @dbtop = o.oid if o.oid > @dbtop
      @db[o.oid]=o
    end
    $stdout.puts "Done database loaded...top oid=#{@dbtop}."
    $stdout.puts "Loading commands..."
    @cmds = Command.load
    $stdout.puts "Done."
    @tits = []
  end

  # Fetch the next available oid.
  # [+return+] An oid.
  def getid
    @dbtop+=1
  end

  # Save the world
  # [+return+] Undefined.
  def save
    File.open('db/world.yaml','w'){|f|YAML::dump(@db.values,f)}
  end

  # Adds a new object to the database.
  # [+obj+] is a reference to object to be added
  # [+return+] Undefined.
  def add(obj)
    @db[obj.oid] = obj
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
    @db[i]
  end

  # Finds a Player object in the database by name.
  # [+nm+] is the string to use in the search.
  # [+return+] Handle to the Player object or nil.
  def find_player_by_name(nm)
    @db.values.find{|o|Player==o.class&&nm==o.name}
  end

  # Finds all the players at a location.
  # [+loc+]    The location oid searched or nil for everywhere.
  # [+return+] Handle to a list of the Player objects.
  def players_at_location(loc)
    @db.values.find_all{|o|(o.class==Player)&&(!loc||loc==o.location)}
  end

  # Finds all connected players
  # [+exempt+] The oid of a player to be exempt from the returned array.
  # [+return+] An array of  connected players
  def players_connected(exempt=nil)
    @db.values.find_all{|o| o.class == Player && o.oid != exempt && o.session}
  end

  # Finds all the players at a location except the passed player.
  # [+loc+]    The location oid searched or nil for everywhere.
  # [+plrid+]  The player oid excepted from the list.
  # [+return+] Handle to a list of the Player objects.
  def other_players_at_location(loc,plrid)
    @db.values.find_all{|o|(o.class==Player)&&(!loc||loc==o.location)&&o.oid!=plrid}
  end

  # Finds all Objects at a location
  # [+loc+]    The location oid searched or nil for everywhere.
  # [+return+] Handle to a list of the Obj objects.
  def objects_at_location(loc)
    @db.values.find_all{|o|(o.class==Obj)&&(!loc||loc==o.location)}
  end

  # Add an Event to the TITS queue.
  # [+e+]      The event to be added.
  # [+return+] Undefined.
  def add_event(from,to,kind,msg=nil)
    @tits.push(Event.new(from,to,kind,msg))
  end

  # Get an Event from the TITS queue.
  # [+return+] The Event or nil
  def get_event
    @tits.shift
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
    $world.players_connected(@player.oid).each {|p|
      $world.add_event(@oid,p.oid,:show,"#{@player.name} has connected.")
    }
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
      while e = $world.get_event
        $world.find_by_oid(e.to).ass(e)
      end
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

#
# Processes command line arguments
#
require 'optparse'
require 'ostruct'
def get_options
  # parse options
  begin
    # The myopts specified on the command line will be collected in *myopts*.
    # We set default values here.
    myopts = OpenStruct.new
    myopts.port = 4000
    myopts.verbose = false

    opts = OptionParser.new do |opts|
      opts.banner = BANNER
      opts.separator ""
      opts.separator "Usage: ruby #{$0} [options]"
      opts.separator ""
      opts.on("-p", "--port PORT", Integer,
        "Select the port the mud will run on (defaults to 4000)") {|myopts.port|}
      opts.on("-v", "--[no-]verbose", "Run verbosely") {|myopts.verbose|}
      opts.on_tail("-h", "--help", "Show this message") do
        puts opts.help
        exit
      end
      opts.on_tail("--version", "Show version") do
        puts "TeensyMud #{Version}"
        exit
      end
    end

    opts.parse!(ARGV)

    return myopts
  rescue OptionParser::ParseError
    puts "ERROR - #{$!}"
    puts "For help..."
    puts " ruby #{$0} --help"
    exit
  end
end


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
  $world=World.new(get_options)
  $engine = Engine.new($world.options.port)
  $engine.run
rescue => e
  $stderr.puts "Exception caught error in server: " + $!
  $stderr.puts $@
  exit
end


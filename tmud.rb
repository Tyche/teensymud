#!/usr/bin/env ruby -w
#
# file::    tmud.rb
# author::  Jon A. Lambert
# version:: 2.6.0
# date::    09/30/2005
#
# This source code copyright (C) 2005 by Jon A. Lambert
# All rights reserved.
#
# Released under the terms of the TeensyMUD Public License
# See LICENSE file for additional information.
#
require 'yaml'
require 'thread'
require 'logger'
require 'pp'

$:.unshift "lib"
$:.unshift "vendor"

require 'publisher'
require 'net/reactor'
require 'command'
require 'database'
require 'farts/farts_parser'

Version = "2.6.0"

# Displayed upon connecting
BANNER=<<-EOH


            This is TeensyMUD version #{Version}

          Copyright (C) 2005 by Jon A. Lambert
 Released under the terms of the TeensyMUD Public License


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
  # The displayed description of the object
  attr_accessor :desc
  # Flag indicating whether this object is interested in timer events
  attr_accessor :powered

  # Create a new Object
  # [+name+]     Every object needs a name
  # [+location+] The object oid containing this object or nil.
  # [+return+]   A handle to the new Object
  def initialize(name,location=nil)
    @name,@location,@oid=name,location,$engine.world.db.getid
    @contents = []
    @farts = {}
    @desc = ""
    @powered = false
    $engine.world.db.get(@location).add_contents(@oid) if @location
  end

  # Add an object to the contents of this object
  # [+oid+] The object id to add
  def add_contents(oid)
    @contents << oid
  end

  # Deletes an object from the contents of this object
  # [+oid+] The object id to delete
  def delete_contents(oid)
    @contents.delete(oid)
  end

  # Returns the contents of the object
  # [+return+] An array of object ids
  def get_contents
    @contents
  end

  # Add a trigger to this object
  # [+oid+] The object id to add
  def add_trigger(t)
    @farts[t.event] = t
  end

  # Deletes a trigger from this object
  # [+oid+] The object id to delete
  def delete_trigger(event)
    event = event.intern if event.respond_to?(:to_str)
    @farts.delete(event)
  end

  # Returns a specific trigger from the object
  # [+return+] A trigger or nil
  def get_trigger(event)
    event = event.intern if event.respond_to?(:to_str)
    @farts[event]
  end

  # Returns the triggers on the object
  # [+return+] An array of triggers
  def get_triggers
    @farts.values
  end

  # Fart handler
  # [+e+]      The event
  # [+return+] true or false
  def fart(ev)
    t = get_trigger(ev.kind)
    if t
      t.execute(ev)
    else
      true
    end
  end

  # Finds all objects contained in this object
  # [+return+] Handle to a array of the objects.
  def objects
    ary = @contents.collect do |oid|
      o = $engine.world.db.get(oid)
      o.class == Obj ? o : nil
    end
    ary.compact
  end

  # Finds all the players contained in this object except the passed player.
  # [+exempt+]  The player oid exempted from the list.
  # [+return+] Handle to a list of the Player objects.
  def players(exempt=nil)
    ary = @contents.collect do |oid|
      o = $engine.world.db.get(oid)
      (o.class == Player && oid != exempt && o.session) ? o : nil
    end
    ary.compact
  end

  # All command input routed through here and parsed.
  # [+m+]      The input message to be parsed
  # [+return+] false or true depending on whether command succeeded.
  def parse(m)
    # match legal command
    m=~/([A-Za-z0-9_@?"'#!]+)(.*)/
    cmd=$1
    arg=$2
    arg.strip! if arg

    # look for a command from our table for objects
    c = $engine.world.ocmds.find(cmd)

    # there are three possibilities here
    case c.size
    when 0   # no commands found
      false
    when 1   # command found
      return self.send(c[0].cmd, arg)
    else     # ambiguous command - tell luser about them.
      false
    end
  end

  # Event handler
  # [+e+]      The event
  # [+return+] Undefined
  def ass(e)
    case e.kind
    when :describe
      msg = "[COLOR=yellow]A #{name} is here[/COLOR]"
      $engine.world.add_event(@oid,e.from,:show,msg)
      fart(e)
    when :get
      plyr = $engine.world.db.get(e.from)
      place = $engine.world.db.get(@location)
      # remove it
      place.delete_contents(@oid)
      # add it
      plyr.add_contents(@oid)
      @location = plyr.oid
      $engine.world.add_event(@oid,e.from,:show,"You get the #{@name}")
      fart(e)
    when :drop
      plyr = $engine.world.db.get(e.from)
      place = $engine.world.db.get(plyr.location)
      # remove it
      plyr.delete_contents(@oid)
      # add it
      place.add_contents(@oid)
      @location = place.oid
      $engine.world.add_event(@oid,e.from,:show,"You drop the #{@name}")
      fart(e)
    when :timer
      fart(e)
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
    super(name)
  end

  # Event handler
  # [+e+]      The event
  # [+return+] Undefined
  def ass(e)
    case e.kind
    when :describe
      msg = "[COLOR=green](#{@oid.to_s}) #{name}[/COLOR]\n#{desc}\n"
      $engine.world.add_event(@oid,e.from,:show,msg)
      fart(e)
    when :describe_exits
      msg = "[COLOR=red]Exits:\n"
      s = @exits.size
      if s == 0
        msg << "None.[/COLOR]"
      else
        i = 0
        @exits.keys.each do |ex|
          msg << ex
          i += 1
          case s - i
          when 1 then s > 2 ? msg << ", and " : msg << " and "
          when 0 then msg << "."
          else
            msg << ", "
          end
        end
        msg << "[/COLOR]"
      end
      $engine.world.add_event(@oid,e.from,:show,msg)
      fart(e)
    when :leave
      plyr = $engine.world.db.get(e.from)
      players(e.from).each do |x|
        $engine.world.add_event(@oid,x.oid,:show, plyr.name + " has left #{e.msg}.") if x.session
      end
      # remove player
      delete_contents(plyr.oid)
      plyr.location = nil
      $engine.world.add_event(@oid,@exits[e.msg],:arrive,plyr.oid)
      fart(e)
    when :arrive
      plyr = $engine.world.db.get(e.msg)
      # add player
      add_contents(plyr.oid)
      plyr.location = @oid
      players(e.msg).each do |x|
        $engine.world.add_event(@oid,x.oid,:show, plyr.name+" has arrived.") if x.session
      end
      plyr.parse('look')
      fart(e)
    else
      super(e)
    end
  end

end

# The Player class is the mother of all players.
# Who's their daddy?
#
class Player < Obj
  include Publisher

  # The Session object this player is connected on or nil if not connected.
  attr_accessor :session, :color

  # Create a new Player object
  # [+name+]    The displayed name of the player.
  # [+passwd+]  The player password in clear text.
  # [+session+] The session object this player is connecting on.
  # [+return+]  A handle to the new Player.
  def initialize(name,passwd,session)
    @session = session
    @passwd = encrypt(passwd)
    super(name,$engine.world.options.home)
    @powered = true

    # session related - only color settable
    @color = false
    @echo = false
    @zmp = false
    @termsize = [80,43]
    @terminal = "unknown"
  end

  # Sends a message to the player if they are connected.
  # [+s+]      The message string
  # [+return+] Undefined.
  def sendto(s)
    publish(s+"\n") if @session
  end

  # Receives messages from a Connection being observed and handles them
  #
  # [+msg+]      The message string
  #
  # This supports the following:
  # [:logged_out] - This symbol from the server informs us that the
  #                 Connection has disconnected in an expected manner.
  # [:disconnected] - This symbol from the server informs us that the
  #                 Connection has disconnected in an unexpected manner.
  #                 There is no practical difference from :logged_out to
  #                 us.
  # [String] - A String is assumed to be input from the Session and we
  #            send it to Player#parse.
  # [Array] - An Array is assumed to be the return value of a query we
  #           issued to the Connection.
  #
  #         <pre>
  #         us     -> Connection
  #             query :color
  #         Connection -> us
  #             [:color, true]
  #         </pre>
  #
  def update(msg)
    case msg
    when :logged_out
      @session = nil
      unsubscribe_all
      $engine.world.db.players_connected(@oid).each do |p|
        $engine.world.add_event(@oid,p.oid,:show,"#{@name} has quit.")
      end
    when :disconnected
      @session = nil
      unsubscribe_all
      $engine.world.db.players_connected(@oid).each do |p|
        $engine.world.add_event(@oid,p.oid,:show,"#{@name} has disconnected.")
      end
    when Array
      $engine.log.debug "Player#update query return - #{msg.inspect}"
      case msg[0]
      when :terminal
        @terminal = msg[1]
      when :termsize
        @termsize = msg[1]
      when :color
        @color = msg[1]
      when :zmp
        @zmp = msg[1]
      when :echo
        @echo = msg[1]
      else
        $engine.log.error "Player#update unknown message - #{msg.inspect}"
      end
    when String
      parse(msg)
    else
      $engine.log.error "Player#update unknown message - #{msg.inspect}"
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
    publish(:logged_out)
    unsubscribe_all
    @session = nil
  end

  # All command input routed through here and parsed.
  # [+m+]      The input message to be parsed
  # [+return+] Undefined.
  def parse(m)
    # match legal command
    m=~/([A-Za-z0-9_@?"'#!\]\[]+)(.*)/
    cmd=$1
    arg=$2
    arg.strip! if arg
    if !cmd
      sendto("Huh?")
      return
    end

    # look for a command in our spanking new table
    c = $engine.world.cmds.find(cmd)

    # add any exits to our command list
    # escape certain characters in cmd
    check = cmd.gsub(/\?/,"\\?")
    check.gsub!(/\#/,"\\#")
    check.gsub!(/\[/,"\\[")
    check.gsub!(/\]/,"\\]")
    $engine.world.db.get(@location).exits.keys.grep(/^#{check}/).each do |ex|
      c << Command.new(:cmd_go,"go #{ex}",nil)
      arg = ex
    end

    # there are three possibilities here
    case c.size
    when 0   # no commands found
      sendto("Huh?")
    when 1   # command found
      self.send(c[0].cmd, arg)
    else     # ambiguous command - tell luser about them.
      ln = "Which did you mean, "
      c.each do |x|
        ln += "\'" + x.name + "\'"
        x.name == c.last.name ? ln += "?" : ln += " or "
      end
      sendto(ln)
    end
  end

  # Event handler
  # [+e+]      The event
  # [+return+] Undefined
  def ass(e)
    case e.kind
    when :describe
      msg = "[COLOR=cyan]#{@name} is here.[/COLOR]"
      $engine.world.add_event(@oid,e.from,:show,msg)
      fart(e)
    when :show
      sendto(e.msg)
      fart(e)
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

# The Hamster class is a timer mechanism that issues timing events
#
class Hamster < Thread

  # Constructor for a Hamster.
  # [+time+]      The interval time for events in flaoting point seconds.
  # [+eventtype+] The symbol that defines the kind of event to be issued.
  # [+return+] A reference to the Hamster.
  def initialize(world, time, eventtype)
    @world = world
    @time = time
    @eventtype = eventtype
    @interested = []
    @mutex = Mutex.new
    super {run}
  end

  # Register one's interest in talking to the Hamster.
  # [+obj+]     The interval time for events in flaoting point seconds.
  def register(obj)
    @mutex.synchronize do
      @interested << obj
    end
  end

  # Unregister from the Hamster.
  # [+obj+]     The interval time for events in flaoting point seconds.
  def unregister(obj)
    @mutex.synchronize do
      @interested.delete(obj)
    end
  end

  # The timing thread loop
  def run
    while true
      sleep @time
      @mutex.synchronize do
        @interested.each do |o|
          @world.add_event(nil, o.oid, @eventtype, nil)
        end
      end
    end
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
# [+db+] is a handle to the database.
# [+cmds+] is a handle to the commands table (a ternary trie).
# [+tits+] is a handle to the tits event queue (an array).
# [+options+] is a handle to the configuration options structure.
class World

  attr_accessor :cmds, :ocmds, :tits, :hamster
  attr_reader :options, :db


  # Create the World.  This loads or creates the database depending on
  # whether it finds it.
  # [+return+] A handle to the World object.
  def initialize(log, options)
    @log, @options = log, options
    @db = Database.new(@log, @options)
    @log.info "Loading commands..."
    @cmds = Command.load("commands.yaml", Player, :Cmd)
    @ocmds = Command.load("obj_cmds.yaml", Obj, :ObjCmd)
    @log.info "Done."
    @tits = []
    @bra = Mutex.new
    @log.info "Releasing Hamster..."
    @hamster = Hamster.new(self, 2.0, :timer)
    @db.objects {|obj| @hamster.register(obj) if obj.powered}
    @log.info "World initialized."
  end

  # Add an Event to the TITS queue.
  # [+e+]      The event to be added.
  # [+return+] Undefined.
  def add_event(from,to,kind,msg=nil)
    @bra.synchronize do
      @tits.push(Event.new(from,to,kind,msg))
    end
  end

  # Get an Event from the TITS queue.
  # [+return+] The Event or nil
  def get_event
    @bra.synchronize do
      @tits.shift
    end
  end
end


# The Incoming class handles connection login and passes them to
# player.
class Incoming
  include Publisher

  # Create an incoming connection.  This is a temporary object that handles
  # login for player and gets them connected.
  # [+conn+]   The session associated with this incoming connection.
  # [+return+] A handle to the incoming object.
  def initialize(conn)
    @conn = conn
    @state = :name
    @checked = 3
    @player = nil
    @initdone = false # keep silent until we're done negotiating
  end

  # Receives messages from a Connection being observed and handles login
  # state.  On successful login the observer status will be transferred
  # to the player object.
  #
  # [+msg+]      The message string
  #
  # This supports the following:
  # [:logged_out] - This symbol from the server informs us that the
  #                 Connection has disconnected in an expected manner.
  # [:disconnected] - This symbol from the server informs us that the
  #                 Connection has disconnected in an unexpected manner.
  #                 There is no practical difference from :logged_out to
  #                 us.
  # [:initdone] - This symbol from the server indicates that the Connection
  #               is done setting up and done negotiating an initial state.
  #               It triggers us to start sending output and parsing input.
  # [String] - A String is assumed to be input from the Session and we
  #            parse and handle it here.
  # [Array] - An Array is assumed to be the return value of a query we
  #           issued to the Connection.  Currently no queries or set
  #           requests are made from Incoming (see Player).
  #
  #         <pre>
  #         us     -> Connection
  #             query :color
  #         Connection -> us
  #             [:color, true]
  #         </pre>
  #
  def update(msg)
    case msg
    when :logged_out, :disconnected
      unsubscribe_all
    when :initdone
      @initdone = true
      publish(BANNER)
      publish("\nlogin> ")
    when String
      if @initdone
        case @state
        when :name
          @login_name = msg
          @player = $engine.world.db.find_player_by_name(@login_name)
          publish("\npassword> ")
          publish([:hide, true])
          @state = :password
        when :password
          @login_passwd = msg
          publish([:hide, false])
          if @player
            if @player.check_passwd(@login_passwd)  # good login
              @player.session = @conn
              login
            else  # bad login
              @checked -= 1
              publish("Sorry wrong password.\n")
              if @checked < 1
                publish("Bye!\n")
                publish(:logged_out)
                unsubscribe_all
              else
                @state = :name
                publish("\nlogin> ")
              end
            end
          else  # new player
            publish("\nCreate new user?\n'Y'|'y' to create, Enter to retry login> ")
            @state = :new
          end
        when :new
          if msg =~ /^[Yy]/
            @player = Player.new(@login_name,@login_passwd,@conn)
            $engine.world.db.put(@player)
            login
          else
            @state = :name
            publish("\nlogin> ")
          end
        end
      end
    else
      $engine.log.error "Incoming#update unknown message - #{msg.inspect}"
    end
  end

private
  # Called on successful login
  def login
    publish([:color, @player.color])

    # Check if this player already logged in
    if @player.subscriber_count > 0
      @player.publish(:reconnecting)
      @player.unsubscribe_all
      @player.sendto("Welcome reconnecting #{@login_name}@#{@conn.sock.peeraddr[2]}!")
    end

    # deregister all observers here and on connection
    unsubscribe_all
    @conn.unsubscribe_all

    # reregister all observers to @player
    @conn.subscribe(@player)
    @player.subscribe(@conn)

    @player.sendto("Welcome #{@login_name}@#{@conn.sock.peeraddr[2]}!")
    $engine.world.db.players_connected(@player.oid).each {|p|
      $engine.world.add_event(@oid,p.oid,:show,"#{@player.name} has connected.")
    }
    @player.publish(:echo)
    @player.publish(:zmp)
    @player.publish(:terminal)
    @player.publish(:termsize)
    @player.parse('look')
  end

end


# The Engine class sets up the server, polls it regularly and observes
# acceptor for incoming connections.
class Engine
  attr_accessor :shutdown
  attr_reader :log, :world

  # Create the an engine.
  # [+port+]   The port passed to create a reactor.
  # [+return+] A handle to the engine.
  def initialize(options)
    @log = Logger.new('logs/engine_log', 'daily')
    @log.datetime_format = "%Y-%m-%d %H:%M:%S "
    # Create the world an object containing most everything.
    @world = World.new(@log, options)
    @log.info "Booting server on port #{options.port}"
    @server = Reactor.new(options.port)
    @incoming = []
    @shutdown = false
  end

  # main loop to run engine.
  # note:: @shutdown never set by anyone yet
  def run
    raise "Unable to start server" unless @server.start(self)
    @log.info "TMUD is ready"
    until @shutdown
      @server.poll(0.2)
      while e = @world.get_event
        @world.db.get(e.to).ass(e)
      end
    end # until
    @server.stop
  end

  # Update is called by an acceptor passing us a new session.  We create
  # an incoming object and set it and the connection to watch each other.
  def update(newconn)
    inc = Incoming.new(newconn)
    # Observe each other
    newconn.subscribe(inc)
    inc.subscribe(newconn)
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
    myopts.home = 1
    myopts.dbname = "db/world.yaml"
    myopts.verbose = false
    myopts.trace = false

    opts = OptionParser.new do |opts|
      opts.banner = BANNER
      opts.separator ""
      opts.separator "Usage: ruby #{$0} [options]"
      opts.separator ""
      opts.on("-p", "--port PORT", Integer,
        "Select the port the mud will run on",
        "  (defaults to 4000)") {|myopts.port|}
      opts.on("-d", "--database DBNAME", String,
        "Select the name of the database the mud will use",
        "  (defaults to \'db/world.yaml\')") {|myopts.dbname|}
      opts.on("-h", "--home LOCATIONID", Integer,
        "Select the object id where new players will start",
        "  (defaults to 1)") {|myopts.home|}
      opts.on("-t", "--[no-]trace", "Trace execution") {|myopts.trace|}
      opts.on("-v", "--[no-]verbose", "Run verbosely") {|myopts.verbose|}
      opts.on_tail("-h", "--help", "Show this message") do
        $stdout.puts opts.help
        exit
      end
      opts.on_tail("--version", "Show version") do
        $stdout.puts "TeensyMud #{Version}"
        exit
      end
    end

    opts.parse!(ARGV)

    return myopts
  rescue OptionParser::ParseError
    $stderr.puts "ERROR - #{$!}"
    $stderr.puts "For help..."
    $stderr.puts " ruby #{$0} --help"
    exit
  end
end


# Setup traps - invoke one of these signals to shut down the mud
def handle_signal(sig)
  if $engine
    $engine.log.warn "Signal caught request to shutdown."
    $engine.log.info "Saving world..."
    $engine.world.db.players_connected.each{|plr|plr.disconnect if plr.session}
    # clear compiled progs out before saving
    $engine.world.db.objects {|o| o.get_triggers.each {|t| t.prog = nil }}
    $engine.world.db.save
  else
    $stderr.log.warn "Signal caught request to shutdown."
    $stderr.log.info "Saving world..."
  end
  exit
end


if $0 == __FILE__
  Signal.trap("INT", method(:handle_signal))
  Signal.trap("TERM", method(:handle_signal))
  Signal.trap("KILL", method(:handle_signal))

  begin
    $engine = Engine.new(get_options)
    if $engine.world.options.trace
      set_trace_func proc { |event, file, line, id, binding, classname|
        printf "%8s %s:%-2d %10s %8s\n", event, file, line, id, classname
      }
    end
    $engine.run
  rescue => e
    if $engine
      $engine.log.error $!
    else
      $stderr.puts "Exception caught error in server: " + $!
      $stderr.puts $@
    end
    exit
  end
end


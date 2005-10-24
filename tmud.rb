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
require 'db/database'
require 'db/gameobject'
require 'db/player'
require 'db/room'
require 'farts/farts_parser'

Version = "2.6.0"

=begin
# Displayed upon connecting
BANNER=<<-EOH


            This is TeensyMUD version #{Version}

          Copyright (C) 2005 by Jon A. Lambert
 Released under the terms of the TeensyMUD Public License


EOH
=end

# Displayed upon connecting
BANNER=<<-EOH
[cursave][home 1,1][clear][currest]


            This is TeensyMUD version #{Version}

          Copyright (C) 2005 by Jon A. Lambert
 Released under the terms of the TeensyMUD Public License


EOH

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
    @ocmds = Command.load("obj_cmds.yaml", GameObject, :ObjCmd)
    @log.info "Done."
    @tits = []
    @bra = Mutex.new
#    @log.info "Releasing Hamster..."
#    @hamster = Hamster.new(self, 2.0, :timer)
#    @db.objects {|obj| @hamster.register(obj) if obj.powered}
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
    @echo = false
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
      @echo = @conn.query(:echo)
      @initdone = true
      publish(BANNER)
      ts = @conn.query(:termsize)
 # ansi test
      publish("[cursave]")
      15.times do
        publish("[home #{rand(ts[1])+1},#{rand(ts[0])+1}]*")
      end
      publish("[currest]")
      prompt("login> ")
    when String
      if @initdone
        case @state
        when :name
          @login_name = msg
          @player = $engine.world.db.find_player_by_name(@login_name)
          prompt("password> ")
          @conn.set(:hide, true)
          @state = :password
        when :password
          @login_passwd = msg
          @conn.set(:hide, false)
          if @player
            if @player.check_passwd(@login_passwd)  # good login
              @player.session = @conn
              login
            else  # bad login
              @checked -= 1
              prompt("Sorry wrong password.\n")
              if @checked < 1
                publish("Bye!\n")
                publish(:logged_out)
                unsubscribe_all
              else
                @state = :name
                publish("login> ")
              end
            end
          else  # new player
            prompt("Create new user?\n'Y'|'y' to create, Enter to retry login> ")
            @state = :new
          end
        when :new
          if msg =~ /^[Yy]/
            @player = Player.new(@login_name,@login_passwd,@conn)
            $engine.world.db.put(@player)
            login
          else
            @state = :name
            prompt("login> ")
          end
        end
      end
    else
      $engine.log.error "Incoming#update unknown message - #{msg.inspect}"
    end
  end

private
  def prompt(msg)
    msg = "\n" + msg if !@echo
    publish(msg)
  end

  # Called on successful login
  def login
    @conn.set(:color, @player.color)

    # Check if this player already logged in
    if @player.subscriber_count > 0
      @player.publish(:reconnecting)
      @player.unsubscribe_all
      @player.sendto("\nWelcome reconnecting #{@login_name}@#{@conn.sock.peeraddr[2]}!")
    end

    # deregister all observers here and on connection
    unsubscribe_all
    @conn.unsubscribe_all

    # reregister all observers to @player
    @conn.subscribe(@player)
    @player.subscribe(@conn)

    @player.sendto("\nWelcome #{@login_name}@#{@conn.sock.peeraddr[2]}!")
    $engine.world.db.players_connected(@player.oid).each {|p|
      $engine.world.add_event(@oid,p.oid,:show,"#{@player.name} has connected.")
    }


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
        if file !~ /\/usr\/lib\/ruby/
          printf "%8s %s:%-2d %10s %8s\n", event, file, line, id, classname
        end
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


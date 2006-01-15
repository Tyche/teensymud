#!/usr/bin/env ruby
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
require 'pp'

$:.unshift "lib"
$:.unshift "vendor"

require 'configuration'
require 'log'
require 'publisher'
require 'net/reactor'
require 'command'
require 'db/properties'
require 'db/gameobject'
require 'db/player'
require 'db/room'
require 'db/account'
require 'event/hamster'
require 'event/eventmanager'
require 'farts/farts_parser'


# Displayed upon connecting
LOGO=<<EOD
\e[0;31m
#######                                           #      ##  #     ##  ######
  ##                                              ##    ###  #     ##  #    ##
  ##                                              ##    ###  #     ##  #     #
  ##     #####   #####   ######   ###### ##    #  ###   ###  #     ##  #     ##
  ##    ##   ##  ##  ##  ###  ##  #   ##  #   ##  ###  ####  #     ##  #     ##
  ##    #    ## ##    #  ##   ##  ##      ##  #   # #  ####  #     ##  #     ##
  ##    ####### #######  ##   ##   ####   ## ##   # #### ##  #     ##  #     ##
  ##    #       ##       ##   ##      ##   ####   # #### ##  #     ##  #    ##
  ##    ##   #   #   ##  ##   ##  #    #   ###    #  ##  ##  ##   ##   #    ##
  ##     #####   #####   ##   ##  ######    ##    #  ##  ##   #####    ######
                                           ##
                                           ##
                                         ###
\e[m
EOD


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
  attr_accessor :cmds, :ocmds, :eventmgr, :hamster
  attr_reader :db
  configuration
  logger 'DEBUG'

  # Create the World.  This loads or creates the database depending on
  # whether it finds it.
  # [+return+] A handle to the World object.
  def initialize
    case options['dbtype']
    when :yaml
require 'db/yamlstore'
      @db = YamlStore.new(options['dbfile'])
    when :gdbm
require 'db/gdbmstore'
      @db = GdbmStore.new(options['dbfile'])
    when :sdbm
require 'db/sdbmstore'
      @db = SdbmStore.new(options['dbfile'])
    when :dbm
require 'db/dbmstore'
      @db = DbmStore.new(options['dbfile'])
    end
    @cmds, @ocmds = Command.load
    @eventmgr = EventManager.new
    log.info "Releasing Hamster..."
    @hamster = Hamster.new(self, 2.0, :timer)
    log.info "World initialized."
  end

  # Finds a Player object in the database by name.
  # [+nm+] is the string to use in the search.
  # [+return+] Handle to the Player object or nil.
  def find_player_by_name(nm)
    @db.each do |o|
      return o if Player == o.class && nm == o.name
    end
    nil
  end

  # Finds all connected players
  # [+exempt+] The id of a player to be exempt from the returned array.
  # [+return+] An array of  connected players
  def players_connected(exempt=nil)
    ary = []
    @db.each do |o|
       ary << o if Player == o.class && o.session && exempt != o.id
    end
    ary
  end

  # memstats scans all objects in memory and produces a report
  # [+return+] a string
  def memstats
    # initialize all counters
    rooms = objs = players = strcount = strsize = ocount = 0

    # scan the ObjectSpace counting things
    ObjectSpace.each_object do |x|
      case x
      when String
        strcount += 1
        strsize += x.size
      when Player
        players += 1
      when Room
        rooms += 1
      when GameObject
        objs += 1
      else
        ocount += 1
      end
    end

    # our report  :
    # :NOTE: sprintf would be better
    memstats=<<EOD
[COLOR=cyan]
----* Memory Statistics *----
  Rooms   - #{rooms}
  Players - #{players}
  Objects - #{objs}
-----------------------------
  Strings - #{strcount}
     size - #{strsize} bytes
  Other   - #{ocount}
-----------------------------
  Total Objects - #{rooms+objs+players+strcount+ocount}
----*                   *----
[/COLOR]
EOD
  end

end



# The Engine class sets up the server, polls it regularly and observes
# acceptor for incoming connections.
class Engine
  attr_accessor :shutdown
  attr_reader :world
  configuration
  logger 'DEBUG'

  # Create the an engine.
  # [+return+] A handle to the engine.
  def initialize
    # Display options
    log.debug "Configuration: #{options.inspect}"
    # Create the world an object containing most everything.
    @world = World.new
    log.info "Booting server on port #{options['server_port'] || 4000}"
    @server = Reactor.new(options['server_port'] || 4000,
      options['server_type'], options['server_io'],
      options['server_negotiation'], options['server_filters'],
      address=nil)
    @incoming = []
    @shutdown = false
    if options['trace']
      set_trace_func proc { |event, file, line, id, binding, classname|
        if file !~ /\/usr\/lib\/ruby/
          printf "%8s %s:%-2d %10s %8s\n", event, file, line, id, classname
        end
      }
    end
  rescue
    log.fatal "Engine initialization failed"
    log.fatal $!
  end

  # main loop to run engine.
  # note:: @shutdown never set by anyone yet
  def run
    Signal.trap("INT", method(:handle_signal))
    Signal.trap("TERM", method(:handle_signal))
    Signal.trap("KILL", method(:handle_signal))

    raise "Unable to start server" unless @server.start(self)
    log.info "Registering objects with hamster..."
    @world.db.each {|obj| @world.hamster.register(obj) if obj.powered}
    log.info "TMUD is ready"
    until @shutdown
      @server.poll(0.2)
      while e = @world.eventmgr.get_event
        @world.db.get(e.to).ass(e)
      end
    end # until
    @server.stop
  rescue
    log.fatal "Engine failed in run"
    log.fatal $!
  end

  # Update is called by an acceptor passing us a new session.  We create
  # an incoming object and set it and the connection to watch each other.
  def update(newconn)
    inc = Account.new(newconn)
    # Observe each other
    newconn.subscribe(inc)
    inc.subscribe(newconn)
  end

  # Setup traps - invoke one of these signals to shut down the mud
  def handle_signal(sig)
    log.warn "Signal caught request to shutdown."
    log.info "Saving world..."
    @world.players_connected.each{|plr|plr.disconnect if plr.session}
    # clear compiled progs out before saving
    @world.db.each {|o| o.get_triggers.each {|t| t.prog = nil }}
    @world.db.save
    @world.db.close
    exit
  end

end


#
# Processes command line arguments
#
def get_options
  # parse options
  begin
    # The myopts specified on the command line will be collected in *myopts*.
    # We set default values here.
    myopts = {}

    opts = OptionParser.new do |opts|
      opts.banner = BANNER
      opts.separator ""
      opts.separator "Usage: ruby #{$0} [options]"
      opts.separator ""
      opts.on("-p", "--port PORT", Integer,
        "Select the port the mud will run on") {|myopts['server_port']|}
      opts.on("-d", "--dbfile DBFILE", String,
        "Select the name of the database file",
        "  (default is 'db/world.yaml')") {|myopts['dbfile']|}
      opts.on("-c", "--config CONFIGFILE", String,
        "Select the name of the configuration file",
        "  (default is 'config.yaml')") {|myopts['configfile']|}
      opts.on("-l", "--logfile LOGFILE", String,
        "Select the name of the log file",
        "  (default is 'logs/server.log')") {|myopts['logfile']|}
      opts.on("-h", "--home LOCATIONID", Integer,
        "Select the object id where new players will start") {|myopts['home']|}
      opts.on("-t", "--[no-]trace", "Trace execution") {|myopts['trace']|}
      opts.on("-v", "--[no-]verbose", "Run verbosely") {|myopts['verbose']|}
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



###########################################################################
# This is start of the main driver.
###########################################################################

if $0 == __FILE__
  begin
    $cmdopts = get_options
    $cmdopts.each do |key,val|
      Configuration.instance.options[key] = val
    end

    $engine = Engine.new
    $engine.run
  end
end


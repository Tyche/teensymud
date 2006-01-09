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
require 'logger'
require 'pp'

$:.unshift "lib"
$:.unshift "vendor"

require 'publisher'
require 'net/reactor'
require 'command'
require 'db/database'
require 'db/properties'
require 'db/gameobject'
require 'db/player'
require 'db/room'
require 'db/account'
require 'event/hamster'
require 'event/eventmanager'
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

LOGO=<<EOH
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
EOH

# Displayed upon connecting
BANNER=<<-EOH
[cursave][home 1,1][clear][currest]
#{LOGO}

                      This is TeensyMUD version #{Version}

                    Copyright (C) 2005 by Jon A. Lambert
           Released under the terms of the TeensyMUD Public License


EOH

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
    @eventmgr = EventManager.new(@log, @options)
    @log.info "Releasing Hamster..."
    @hamster = Hamster.new(self, 2.0, :timer)
    @db.objects {|obj| @hamster.register(obj) if obj.powered}
    @log.info "World initialized."
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
    # Display options
    @log.info options.inspect
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
      while e = @world.eventmgr.get_event
        @world.db.get(e.to).ass(e)
      end
    end # until
    @server.stop
  end

  # Update is called by an acceptor passing us a new session.  We create
  # an incoming object and set it and the connection to watch each other.
  def update(newconn)
    inc = Account.new(newconn)
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


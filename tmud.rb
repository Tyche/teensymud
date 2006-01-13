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
require 'db/database'
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
    @db = Database.new
    @cmds, @ocmds = Command.load
    @eventmgr = EventManager.new
    log.info "Releasing Hamster..."
    @hamster = Hamster.new(self, 2.0, :timer)
    @db.objects {|obj| @hamster.register(obj) if obj.powered}
    log.info "Reticulating spleens..."
    log.info "World initialized."
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
    log.debug "Configuration: #{options}"
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
    @world.db.players_connected.each{|plr|plr.disconnect if plr.session}
    # clear compiled progs out before saving
    @world.db.objects {|o| o.get_triggers.each {|t| t.prog = nil }}
    @world.db.save
    exit
  end

end


###########################################################################
# This is start of the main driver.
###########################################################################

if $0 == __FILE__
  begin
    $engine = Engine.new
    $engine.run
  end
end


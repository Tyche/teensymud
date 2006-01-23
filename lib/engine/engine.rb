#
# file::    engine.rb
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
$:.unshift "lib" if !$:.include? "lib"
$:.unshift "vendor" if !$:.include? "vendor"

require 'singleton'

require 'configuration'
require 'log'
require 'net/reactor'
require 'engine/world'
require 'event/eventmanager'
require 'db/room'
require 'db/player'
require 'db/gameobject'
require 'db/account'

# The Engine class sets up the server, polls it regularly and observes
# acceptor for incoming connections.
class Engine
  include Singleton
  configuration
  logger 'DEBUG'

  attr_accessor :shutdown
  attr_reader :world, :db, :eventmgr

  # Create the an engine.
  # [+return+] A handle to the engine.
  def initialize
    # Display options
    log.debug "Configuration: #{options.inspect}"
    @shutdown = false
    if options['trace']
      set_trace_func proc { |event, file, line, id, binding, classname|
        if file !~ /\/usr\/lib\/ruby/
          printf "%8s %s:%-2d %10s %8s\n", event, file, line, id, classname
        end
      }
    end
  end

  # main loop to run engine.
  # note:: @shutdown never set by anyone yet
  def run
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

    # Get the world object
    @world = @db.get(0)
    log.debug @world.inspect
    @db.makenoswap(0)
    @world.startup

    @eventmgr = EventManager.new
    log.info "Booting server on port #{options['server_port'] || 4000}"
    @server = Reactor.new(options['server_port'] || 4000,
      options['server_type'], options['server_io'],
      options['server_negotiation'], options['server_filters'],
      address=nil)

    raise "Unable to start server" unless @server.start(self)
    log.info "TMUD is ready"

    Signal.trap("INT", method(:handle_signal))
    Signal.trap("TERM", method(:handle_signal))
    Signal.trap("KILL", method(:handle_signal))
    until @shutdown
      @server.poll(0.2)
      while e = @eventmgr.get_event
        @db.get(e.to).ass(e)
      end
    end # until
    @world.shutdown
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
    @world.shutdown
    @server.stop
    log.info "Saving world..."
    # clear compiled progs out before saving
    @db.each {|o| o.get_triggers.each {|t| t.prog = nil } if o.respond_to?(:get_triggers) }
    @db.save
    @db.close
    exit
  end

end



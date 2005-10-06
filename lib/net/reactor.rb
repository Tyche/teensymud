#
# file::    reactor.rb
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

require 'logger'

require 'net/acceptor'
require 'net/connector'

#
# The Reactor class defines a representation of a multiplexer based on
# a non-blocking select() server.
#
# The network design is based on the Mesh project NetworkService code
# which was translated almost directly from C++, warts and all, which in
# turn is based on Schmidt's Acceptor/Connector/Reactor patterns which
# may be found at http://citeseer.ist.psu.edu/schmidt97acceptor.html
# for an idea of how all these classes are supposed to interelate.
class Reactor
  attr :log

  # Constructor for Reactor
  # [+port+] The port the server will listen on/client will connect to.
  # [+opts+] Optional array of options passed to all participants.
  #   Valid options are
  #     :server  - run reactor as server (default)
  #     :client  - run reactor as client
  #     :sockio  - use sockio as io handler (default)
  #     :lineio  - use lineio as io handler
  #     :packetio  - use packetio as io handler
  #     :filter  - attach dummy filter
  #     :debugfilter - attach debug filter (default)
  #     :telnetfilter - attach telnet filter (default)
  #        :sga, :echo, :naws, :ttype, :zmp (negotiate default)
  #        :binary
  #     :colorfilter - attach color filter (default)
  #     :terminalfilter - attach terminal filter
  #
  # [+address+] Optional address for outgoing connection.
  #
  def initialize(port, opts=[:server, :sockio, :debugfilter,
                             :telnetfilter, :terminalfilter,
                               :sga, :echo, :naws, :ttype, :zmp,
                             :colorfilter],
                             address=nil)
    @port = port       # port server will listen on
    @shutdown = false  # Flag to indicate that server is shutting down.
    @acceptor = nil    # Listening socket for incoming connections.
    @connector = nil   # Connecting socket for outgoing connections.
    @registry = []     # list of sessions
    @opts = opts       # array of options - symbols
    @address = address # Address for Connector.
  end

  # Start initializes the reactor and gets it ready to accept incoming
  # connections.
  # [+engine+] The client engine that will be observing the acceptor.
  # [+return+'] true if server boots correctly, false if an error occurs.
  def start(engine)
    # Create an acceptor to listen for this server.
    if @opts.include? :client
      @log = Logger.new('logs/net_client_log', 'daily')
      @log.datetime_format = "%Y-%m-%d %H:%M:%S "
      @connector = Connector.new(self, @port, @opts, @address)
      @connector.subscribe(engine)
      return false if !@connector.init
    else
      @log = Logger.new('logs/net_log', 'daily')
      @log.datetime_format = "%Y-%m-%d %H:%M:%S "
      @acceptor = Acceptor.new(self, @port, @opts)
      return false if !@acceptor.init
      @acceptor.subscribe(engine)
    end
    true
  rescue
    @log.error "Reactor#start"
    @log.error $!
    false
  end

  # stop requests each of the connections to disconnect in the
  # server's user list, deletes the connections, and erases them from
  # the user list.  It then closes its own listening port.
  def stop
    @registry.each {|s| s.closing = true}
    @acceptor.unsubscribe_all if @acceptor
    @connector.unsubscribe_all if @connector
    @log.info "Reactor#shutdown: Reactor shutting down"
    @log.close
  end

  # poll starts the Reactor running to process incoming connection, input and
  # output requests.  It also executes commands from input requests.
  # [+tm_out*] time to poll in seconds
  def poll(tm_out)
    # Reset our socket interest set
    infds = [];outfds = [];oobfds = []
    @registry.each do |s|
      if s.is_readable?
        infds << s.sock
        oobfds << s.sock
      end
      if s.is_writable?
        outfds << s.sock
      end
    end

    # Poll our socket interest set
    infds,outfds,oobfds = select(infds, outfds, oobfds, tm_out)

    # Dispatch events to handlers
    @registry.each do |s|
      s.handle_output if outfds && outfds.include?(s.sock)
      s.handle_oob if oobfds && oobfds.include?(s.sock)
      s.handle_input if infds && infds.include?(s.sock)
      s.handle_close if s.closing
      # special handling for Telnet initialization
      if @opts.include?(:telnetfilter) && s.respond_to?(:initdone) && !s.initdone
        s.pstack.set(:init_subneg, true)
      end
    end
  rescue
    @log.error "Reactor#poll"
    @log.error $!
    stop
    raise
  end

  # register adds a session to the registry
  # [+session+]
  def register(session)
    @registry << session
  end

  # unregister removes a session from the registry
  # [+session+]
  def unregister(session)
    @registry.delete(session)
  end

end

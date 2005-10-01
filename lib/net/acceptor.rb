#
# file::    acceptor.rb
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

require 'fcntl'

require 'net/session'
require 'net/connection'

# The acceptor class handles client connection requests for a reactor
#
class Acceptor < Session

  # Create a new acceptor object
  # [+server+]  The reactor this acceptor is associated with.
  # [+port+]    The port this acceptor will listen on.
  # [+returns+] An acceptor object
  def initialize(server, port, opts)
    @port = port
    @opts = opts
    super(server)
  end

  # init is called before using the acceptor
  # [+returns+] true is acceptor is properly initialized
  def init
    # Open a socket for the server to listen on.
    @sock = TCPServer.new('0.0.0.0', @port)
    #@sock.setsockopt(Socket::SOL_SOCKET, Socket::SO_REUSEADDR, 1)
    #@sock.setsockopt(Socket::SOL_SOCKET, Socket::SO_LINGER, 0)
    unless RUBY_PLATFORM =~ /win32/
      @sock.fcntl(Fcntl::F_SETFL, Fcntl::O_NONBLOCK)
    end
    @accepting = true
    @server.register(self)
    true
  rescue Exception
    @server.log.error "Acceptor#init"
    @server.log.error $!
    false
  end

  # handle_input is called when an pending connection occurs on the
  # listening socket's port.  This function creates a Connection object
  # and calls it's init routine.
  def handle_input
    sckt = @sock.accept
    if sckt
      unless RUBY_PLATFORM =~ /win32/
        sckt.fcntl(Fcntl::F_SETFL, Fcntl::O_NONBLOCK)
      end
      c = Connection.new(@server, sckt, @opts)
      if c.init
        @server.log.info "(#{c.object_id}) Connection accepted."
        message(c)
      end
    else
      raise "Error in accepting connection."
    end
  rescue Exception
    @server.log.error "Acceptor#handle_input"
    @server.log.error $!
  end

  # handle_close is called when a close event occurs for this acceptor.
  def handle_close
    @accepting = false
    @server.unregister(self)
    @sock.close
  rescue Exception
    @server.log.error "Acceptor#handle_close"
    @server.log.error $!
  end

end



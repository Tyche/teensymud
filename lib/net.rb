#
# file::    net.rb
# author::  Jon A. Lambert
# version:: 2.5.4
# date::    09/22/2005
#
# This source code copyright (C) 2005 by Jon A. Lambert
# All rights reserved.
#
# Released under the terms of the TeensyMUD Public License
# See LICENSE file for additional information.
#
# The network design is based on the Mesh project NetworkService code
# which was translated almost directly from C++, warts and all, which in
# turn is based on Schmidt's Acceptor/Connector/Reactor patterns which
# may be found at http://citeseer.ist.psu.edu/schmidt97acceptor.html
# for an idea of how all these classes are supposed to interelate.

require 'socket'
require 'logger'
require 'fcntl'
require 'observer'

if $0 == __FILE__
  $:.unshift "../vendor"
end

require 'filter'
require 'telnetcodes'

# The SockIO class implements the low level interface for TCP sockets.
#
class SockIO

  # Creates a new SockIO object
  # [+sock+]    The socket which will be used
  # [+bufsize+] The size of the buffer to use (default is 8192)
  def initialize(sock, bufsize=8192)
    @sock,@bufsize=sock,bufsize
    @inbuffer = ""
    @outbuffer = ""
  end

  # read will receive a data from the socket.
  # [+return+] The data read
  #
  # [+IOError+]  A sockets error occurred.
  # [+EOFError+] The connection has closed normally.
  def read
    @sock.recv(@bufsize)
  end

  # write will transmit a message to the socket
  # [+msg+]    The message string to be sent.
  # [+return+] false if more data to be written, true if all data written
  #
  # [+IOError+]  A sockets error occurred.
  # [+EOFError+] The connection has closed normally.
  def write(msg)
    @outbuffer << msg
    n = @sock.send(@outbuffer, 0)
    # save unsent data for next call
    @outbuffer.slice!(0...n)
    @outbuffer.size == 0
  rescue Exception
    @outbuffer = ""  # Does it really matter?
    raise
  end

  # write_flush will kill the output buffer
  def write_flush
    @outbuffer = ""
  end

  # read_flush will kill the input buffer
  def read_flush
    @inbuffer = ""
  end

  # read_urgent will receive urgent data from the socket.
  # [+return+] The data read
  #
  # [+IOError+]  A sockets error occurred.
  # [+EOFError+] The connection has closed normally.
  def read_urgent
    @sock.recv(@bufsize, Socket::MSG_OOB)
  end

  # write_urgent will write urgent data to the socket.
  # [+msg+]    The message string to be sent.
  #
  # [+IOError+]  A sockets error occurred.
  # [+EOFError+] The connection has closed normally.
  def write_urgent(msg)
    @sock.send(msg, Socket::MSG_OOB)
  end

end

# The LineIO class implements a line-orient interface for TCP sockets.
# It's a specialization of sockio.  This class is intended for line-oriented
# protocols.
#
class LineIO < SockIO

  # Creates a new LineIO object
  # [+sock+]    The socket which will be used
  # [+bufsize+] The size of the buffer to use (default is 8192)
  def initialize(sock, bufsize=8192)
    super(sock,bufsize)
  end

  # read will receive a set of lines from the socket.  A line may be
  # terminated by CRLF, CRNUL, LFCR, CR, or LF.  Not yet terminated lines
  # are left in the @inbuffer.
  # [+return+] One or more complete lines or nil.
  #
  # [+IOError+]  A sockets error occurred.
  # [+EOFError+] The connection has closed normally.
  def read
    @inbuffer << @sock.recv(@bufsize)
    @inbuffer.gsub!(/\r\n|\r\x00|\n\r|\r|\n/,"\n")
    pos = @inbuffer.rindex("\n")
    if pos
      ln = @inbuffer.slice!(0..pos)
      return ln
    end
    nil
  end

end

# The PacketIO class implements a mechanism to send and recv packets
# delimited by a length prefix which is assumed to be a 4 bytes integer
# in network byte order.
#
class PacketIO < SockIO

  # Creates a new PackIO object
  # [+sock+]    The socket which will be used
  # [+bufsize+] The size of the buffer to use (default is 16K)
  def initialize(sock, bufsize=16380)
    @sock = sock
    @bufsize = bufsize + 4 # round out with prefix bytes
    @inbuffer = ""
    @outbuffer = ""
    @packet_size = 0
    @prefix_found = false
  end

  # read will receive a data from the socket.
  # [+return+] The data read
  #
  # [+IOError+]  A sockets error occurred.
  # [+EOFError+] The connection has closed normally.
  def read
    @inbuffer << @sock.recv(@bufsize)
    if !@prefix_found
      # start of packet
      if @inbuffer.size >= 4
        sizest = @inbuffer.slice!(0..3)
        @packet_size = sizest.unpack("N")[0]
        @prefix_found = true
        if @packet_size > @bufsize
          @inbuffer = ""
          @packet_size = 0
          @prefix_found = false
          puts "Discarding packet: Buffer size exceeded (PACKETSIZE=#{@packet_size} STRING='#{sizest}')"
          return nil
        end
      else
        return nil # not enough data yet
      end
    else
      if @inbuffer.size >= @packet_size
        # We have it
        @prefix_found = false
        ps = @packet_size
        @packet_size = 0
        return @inbuffer.slice!(0...ps).chop  # chop off NUL
      else
        # Dont have it all yet.
        return nil
      end
    end
  end

  # write will transmit a packet to the socket, we calculated the size here
  # [+msg+]    The message string to be sent.
  # [+return+] false if more data to be written, true if all data written
  #
  # [+IOError+]  A sockets error occurred.
  # [+EOFError+] The connection has closed normally.
  def write(msg)
    if !msg.nil? || !msg.empty?
      @outbuffer << [msg.length].pack("N") << msg
    end
    n = @sock.send(@outbuffer, 0)
    # save unsent data for next call
    @outbuffer.slice!(0...n)
    @outbuffer.size == 0
  rescue Exception
    @outbuffer = ""  # Does it really matter?
    raise
  end

end

# The session class is a base class contains the minimum amount of
# attributes to reasonably maintain a socket session with a client.
#
class Session
  include Observable

  attr_reader :sock
  attr_accessor :accepting, :connected, :closing, :write_blocked

  # Create a new session object
  # Used when opening both an acceptor or connection.
  # [+server+]  The reactor or connector this session is associated with.
  # [+sock+]    Nil for acceptors or the socket for connections.
  # [+returns+] A session object.
  def initialize(server, sock=nil)
    @server = server   # Reactor or connector associated with this session.
    @sock = sock       # File descriptor handle for this session.
    @addr = ""         # Network address of this socket.
    @accepting=@connected=@closing=@write_blocked=false
  end

  # init is called before using the session.
  # [+returns+] true is session object properly initialized
  def init
    true
  end

  # handle_input is called when an input event occurs for this session.
  def handle_input
  end

  # handle_output is called when an output event occurs for this session.
  def handle_output
  end

  # handle_close is called when a close event occurs for this session.
  def handle_close
  end

  # handle_oob is called when an out of band data event occurs for this
  # session.
  def handle_oob
  end

  # is_readable? tests if the socket is a candidate for select read
  # {+return+] true if so, false if not
  def is_readable?
    @connected || @accepting
  end

  # is_writable? tests if the socket is a candidate for select write
  # {+return+] true if so, false if not
  def is_writable?
    @write_blocked
  end

  # Sends a notification message to all the our Observers.
  # Symbols, Arrays and Strings are understood
  # [+msg+] The message to send.
  def message(msg)
    changed
    notify_observers(msg)
  end

end

# The connection class maintains a socket connection with a
# reactor and handles all events dispatched by the reactor.
#
class Connection < Session
  attr :server
  attr :initdone
  attr :pstack
  attr :sockio

  # Create a new connection object
  # [+server+]  The reactor this connection is associated with.
  # [+sock+]    The socket for this connection.
  # [+returns+] A connection object.
  def initialize(server, sock, opts)
    super(server, sock)
    @opts = opts
    if @opts.include? :lineio
      @sockio = LineIO.new(@sock)
    elsif @opts.include? :packetio
      @sockio = PacketIO.new(@sock)
    else
      @sockio = SockIO.new(@sock)
    end
    @inbuffer = ""              # buffer lines waiting to be processed
    @outbuffer = ""             # buffer lines waiting to be output
    if @opts.include? :telnetfilter
      @initdone = false           # keeps silent until we're done with negotiations
    else
      @initdone = true
    end
    @pstack = ProtocolStack.new(self, @opts)
  end

  # init is called before using the connection.
  # [+returns+] true is connection is properly initialized
  def init
    @addr = @sock.peeraddr[2]
    @connected = true
    @server.register(self)
    @server.log.info "(#{self.object_id}) New Connection on '#{@addr}'"
    @pstack.filter_call(:init,nil)
    true
  rescue Exception
    @server.log.error "(#{self.object_id}) Connection#init"
    @server.log.error $!
    false
  end

  # handle_input is called to order a connection to process any input
  # waiting on its socket.  Input is parsed into lines based on the
  # occurance of the CRLF terminator and pushed into a buffer
  # which is a list of lines.  The buffer expands dynamically as input
  # is processed.  Input that has yet to see a CRLF terminator
  # is left in the connection's inbuffer.
  def handle_input
    buf = @sockio.read
    return if buf.nil?
    buf = @pstack.filter_call(:filter_in,buf)
    if @opts.include?(:packetio) || @opts.include?(:client)
      message(buf)
    else
      @inbuffer << buf
      if @initdone  # Just let buffer fill until we indicate we're done
                    # negotiating.  Set by calling initdone from TelnetFilter
        while p = @inbuffer.index("\n")
          ln = @inbuffer.slice!(0..p).chop
          message(ln)
        end
      end
    end
  rescue EOFError, Errno::ECONNRESET, Errno::ECONNABORTED
    @closing = true
    message(:logged_out)
    delete_observers
    @server.log.info "(#{self.object_id}) Connection '#{@addr}' disconnecting"
    @server.log.error $!
  rescue Exception
    @closing = true
    message(:disconnected)
    delete_observers
    @server.log.error "(#{self.object_id}) Connection#handle_input"
    @server.log.error $!
  end

  # handle_output is called to order a connection to process any output
  # waiting on its socket.
  def handle_output
    @outbuffer = @pstack.filter_call(:filter_out,@outbuffer)
    done = @sockio.write(@outbuffer)
    @outbuffer = ""
    if done
      @write_blocked = false
    else
      @write_blocked = true
    end
  rescue EOFError, Errno::ECONNABORTED, Errno::ECONNRESET
    @closing = true
    message(:logged_out)
    delete_observers
    @server.log.info "(#{self.object_id}) Connection '#{@addr}' disconnecting"
  rescue Exception
    @closing = true
    message(:disconnected)
    delete_observers
    @server.log.error "(#{self.object_id}) Connection#handle_output"
    @server.log.error $!
  end

  # handle_close is called to when an close event occurs for this session.
  def handle_close
    @connected = false
    message(:logged_out)
    delete_observers
    @server.log.info "(#{self.object_id}) Connection '#{@addr}' closing"
    @server.unregister(self)
#    @sock.shutdown   # odd errors thrown with this
    @sock.close
  rescue Exception
    @server.log.error "(#{self.object_id}) Connection#handle_close"
    @server.log.error $!
  end

  # handle_oob is called when an out of band data event occurs for this
  # session.
  def handle_oob
    buf = @sockio.read_urgent
    @server.log.debug "(#{self.object_id}) Connection urgent data received - '#{buf[0]}'"
    @pstack.set(:urgent, true)
    buf = @pstack.filter_call(:filter_in,buf)
  rescue Exception
    @server.log.error "(#{self.object_id}) Connection#handle_oob"
    @server.log.error $!
  end

  # This is called from TelnetFilter when we are done with negotiations.
  # The event :initdone wakens observer to begin user activity
  def set_initdone
    @initdone = true
    message(:initdone)
  end


  # Update will be called when the object the connection is observing
  # wants to notify us of a change in state or new message.
  # When a new connection is accepted in acceptor that connection
  # is passed to the observer of the acceptor which allows the client
  # to attach an observer to the connection and make the connection
  # an observer of that object.  We need to keep both sides interest
  # in each other limited to a narrow but flexible interface to
  # prevent tight coupling.
  #
  # This supports the following:
  # [:logged_out] - This symbol message from the client is a request to
  #               close the Connection.  It is handled here.
  # [String] - A String is assumed to be output and placed in our
  #            @outbuffer.
  # [Symbol] - A Symbol not handled here is assumed to be a query and
  #            its handling is delegated to the ProtocolStack, the result
  #            of which is a pair immediately sent back to as a message
  #            to the client.
  #
  #         <pre>
  #         client -> us
  #             :echo
  #         us     -> ProtocolStack
  #             query(:echo)
  #         ProtocolStack -> us
  #             [:echo, true]
  #         us -> client
  #             [:echo, true]
  #         </pre>
  #
  # [Array] - An Array not handled here is assumed to be a set command and
  #           its handling is delegated to the ProtocolStack.
  #
  #         <pre>
  #         client -> us
  #             [:color, true]
  #         us     -> ProtocolStack
  #             set(:color, true)
  #         </pre>
  #
  def update(msg)
    case msg
    when :logged_out
      @closing = true
    when :reconnecting
      delete_observers
      @server.log.info "(#{self.object_id}) Connection '#{@addr}' closing for reconnection"
      @server.unregister(self)
  #    @sock.shutdown   # odd errors thrown with this
      @sock.close
    when Array    # Arrays are assumed to be
      @pstack.set(msg[0],msg[1])
    when Symbol
      message(@pstack.query(msg))
    when String
      sendmsg(msg)
    else
      @server.log.error "(#{self.object_id}) Connection#update - unknown message '#{@msg.inspect}'"
    end
  end

  # sendmsg places a message on the Connection's output buffer.
  # [+msg+]  The message, a reference to a buffer
  def sendmsg(msg)
    @outbuffer << msg
    @write_blocked = true  # change status to write_blocked
  end

end

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


# The Connector class handles outgoing connections
#
class Connector < Session

  # Create a new Connector object
  # [+server+]  The reactor this Connector is associated with.
  # [+port+]    The port this Connector will listen on.
  # [+address+] The address to connect to.
  # [+returns+] An Connector object
  def initialize(server, port, opts, address)
    @port = port
    @opts = opts
    @address = address
    super(server)
  end

  # init is called before using the Connector
  # [+returns+] true is acceptor is properly initialized
  def init
    # Open a socket for the server to connect on.
    @sock = TCPSocket.new(@address , @port)
    #@sock.setsockopt(Socket::SOL_SOCKET, Socket::SO_REUSEADDR, 1)
    #@sock.setsockopt(Socket::SOL_SOCKET, Socket::SO_LINGER, 0)
    unless RUBY_PLATFORM =~ /win32/
      @sock.fcntl(Fcntl::F_SETFL, Fcntl::O_NONBLOCK)
    end
    c = Connection.new(@server, @sock, @opts)
    if c.init
      @server.log.info "(#{c.object_id}) Connection made."
      message(c)
      true
    else
      false
    end
  rescue Exception
    @server.log.error "Connector#init"
    @server.log.error $!
    false
  end

  # handle_close is called when a close event occurs for this Connector.
  def handle_close
    @sock.close
  rescue Exception
    @server.log.error "Connector#handle_close"
    @server.log.error $!
  end

end

#
# The Reactor class defines a representation of a multiplexer.
# It defines the traditional non-blocking select() server.
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
                             :telnetfilter,
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
      @connector.add_observer(engine)
      return false if !@connector.init
    else
      @log = Logger.new('logs/net_log', 'daily')
      @log.datetime_format = "%Y-%m-%d %H:%M:%S "
      @acceptor = Acceptor.new(self, @port, @opts)
      return false if !@acceptor.init
      @acceptor.add_observer(engine)
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
    @acceptor.delete_observers if @acceptor
    @connector.delete_observers if @connector
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

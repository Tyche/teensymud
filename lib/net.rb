#
# file::    net.rb
# author::  Jon A. Lambert
# version:: 2.5.0
# date::    09/16/2005
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

  # read will receive a line from the socket.  A line may be terminated by
  # LF, CR, CRNUL, LFNUL, CRLF or LFCR.
  # [+return+] The data read
  #
  # [+IOError+]  A sockets error occurred.
  # [+EOFError+] The connection has closed normally.
  def read
    # @sock.sysread(@bufsize)
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
    #n = @sock.syswrite(tmp)
    n = @sock.send(@outbuffer, 0)
    # save unsent data for next call
    @outbuffer.slice!(0...n)
    @outbuffer.size == 0
  rescue Exception
    @outbuffer = ""  # Does it really matter?
    raise
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
    #@inbuffer << @sock.sysread(@bufsize)
    @inbuffer << @sock.recv(@bufsize)
    @inbuffer.gsub!(/\r\n|\r\x00|\n\r|\r|\n/,"\n")
    pos = @inbuffer.rindex("\n")
    if pos
      msg = @inbuffer[0..pos+1]
      @inbuffer.slice!(0..pos+1)
      return msg
    end
    nil
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

end

# The connection class maintains a socket connection with a
# reactor and handles all events dispatched by the reactor.
#
class Connection < Session
  attr :server

  # Create a new connection object
  # [+server+]  The reactor this connection is associated with.
  # [+sock+]    The socket for this connection.
  # [+returns+] A connection object.
  def initialize(server, sock)
    super(server, sock)
    @sockio = SockIO.new(@sock) # Object that handles low level Socket I/O
                                # Should be configurable
    @filters = {}
    @filters[:telnet] = TelnetFilter.new(self,
       {
         TelnetCodes::SGA => true,
         TelnetCodes::NAWS => true,
         TelnetCodes::TTYPE => true
       })
    @inbuffer = ""              # buffer lines waiting to be processed
    @outbuffer = ""             # buffer lines waiting to be output
  end

  # init is called before using the connection.
  # [+returns+] true is connection is properly initialized
  def init
    @addr = @sock.addr[2]
    @connected = true
    @server.register(self)
    @server.log.info "(#{self.object_id}) New Connection on '#{@addr}'"
    @filters.each {|k,v| v.init}
    true
  rescue Exception
    @server.log.error "(#{self.object_id}) Error-Connection#init"
    @server.log.error $!
    false
  end

  # Update will be called when the object the connection is observing
  # has notified us of a change in state or new message.
  # When a new connection is accepted in acceptor that connection
  # is passed to the observer of the acceptor which allows the client
  # to attach an observer to the connection and make the connection
  # an observer of that object.  In this case we want to keep this
  # side real simple to avoid "unnecessary foreign entanglements".
  # We simply support a message to be sent to the socket or a token
  # indicating the clent wants to disconnect this connection.
  def update(msg)
    case msg
    when :logged_out then @closing = true
    when :hide
      @filters[:telnet].offer_us(TelnetCodes::ECHO, true)
    when :unhide
      @filters[:telnet].offer_us(TelnetCodes::ECHO, false)
    when :init
      sendmsg(TelnetCodes::IAC.chr + TelnetCodes::SB.chr + TelnetCodes::TTYPE.chr +
         1.chr + TelnetCodes::IAC.chr + TelnetCodes::SE.chr)
    else
      sendmsg(msg)
    end
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
    @inbuffer << buf
    @filters.each {|k,v| @inbuffer = v.filter_in(@inbuffer)}
    p = @inbuffer.rindex("\n")
    return if p.nil?
    buf = @inbuffer.slice!(0..p)
    buf.split(/\n/).each do |ln|
      changed
      notify_observers(ln)
    end
  rescue EOFError, Errno::ECONNABORTED
    @closing = true
    changed
    notify_observers(:logged_out)
    delete_observers
    @server.log.info "(#{self.object_id}) Connection '#{@addr}' disconnecting"
  rescue Exception
    @closing = true
    changed
    notify_observers(:disconnected)
    delete_observers
    @server.log.error "(#{self.object_id}) Connection#handle_input"
    @server.log.error $!
  end

  # handle_output is called to order a connection to process any output
  # waiting on its socket.
  def handle_output
    @filters.each {|k,v| @outbuffer = v.filter_out(@outbuffer)}
    done = @sockio.write(@outbuffer)
    @outbuffer = ""
    if done
      @write_blocked = false
    else
      @write_blocked = true
    end
  rescue EOFError, Errno::ECONNABORTED
    @closing = true
    changed
    notify_observers(:logged_out)
    delete_observers
    @server.log.info "(#{self.object_id}) Connection '#{@addr}' disconnecting"
  rescue Exception
    @closing = true
    changed
    notify_observers(:disconnected)
    delete_observers
    @server.log.error "(#{self.object_id}) Connection#handle_output"
    @server.log.error $!
  end

  # handle_close is called to when an close event occurs for this session.
  def handle_close
    @connected = false
    changed
    notify_observers(:logged_out)
    delete_observers
    @server.log.info "(#{self.object_id}) Connection '#{@addr}' closing"
    @server.unregister(self)
#    @sock.shutdown   # odd errors thrown with this
    @sock.close
  rescue Exception
    @server.log.error "(#{self.object_id}) Connection#handle_close"
    @server.log.error $!
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
  def initialize(server, port)
    @port = port
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
  rescue Exception
    @server.log.error "Acceptor#init"
    @server.log.error $!
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
      c = Connection.new(@server, sckt)
      if c.init
        @server.log.info "(#{c.object_id}) Connection accepted."
        changed
        notify_observers(c)
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

#
# The Reactor class defines a representation of a multiplexer.
# It defines the traditional non-blocking select() server.
class Reactor
  attr :log

  # Constructor for Reactor
  # [+port+] The port the server will listen on.
  def initialize(port)
    @port = port       # port server will listen on
    @shutdown = false  # Flag to indicate that server is shutting down.
    @acceptor = nil    # Listening socket for incoming connections.
    @registry = []     # list of sessions
  end

  # Start initializes the reactor and gets it ready to accept incoming
  # connections.
  # [+engine+] The client engine that will be observing the acceptor.
  # [+return+'] true if server boots correctly, false if an error occurs.
  def start(engine)
    @log = Logger.new('logs/net_log', 'daily')
    @log.datetime_format = "%Y-%m-%d %H:%M:%S"
    # Create an acceptor to listen for this server.
    @acceptor = Acceptor.new(self, @port)
    return false if !@acceptor.init
    @acceptor.add_observer(engine)
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
    @log.info "INFO-Reactor#shutdown: Reactor shutting down"
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

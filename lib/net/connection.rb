#
# file::    connection.rb
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

require 'net/session'
require 'net/sockio'
require 'net/lineio'
require 'net/packetio'
require 'protocol/protocolstack'

# The connection class maintains a socket connection with a
# reactor and handles all events dispatched by the reactor.
#
class Connection < Session
  logger 'DEBUG'
  attr :server
  attr :initdone
  attr :pstack
  attr :sockio
  attr_accessor :inbuffer, :outbuffer # filters need to this in charmode

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
    log.info "(#{self.object_id}) New Connection on '#{@addr}'"
    @pstack.filter_call(:init,nil)
    true
  rescue Exception
    log.error "(#{self.object_id}) Connection#init"
    log.error $!
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
      publish(buf)
    else
      @inbuffer << buf
      if @initdone  # Just let buffer fill until we indicate we're done
                    # negotiating.  Set by calling initdone from TelnetFilter
        while p = @inbuffer.index("\n")
          ln = @inbuffer.slice!(0..p).chop
          publish(ln)
        end
      end
    end
  rescue EOFError, Errno::ECONNRESET, Errno::ECONNABORTED
    @closing = true
    publish(:logged_out)
    unsubscribe_all
    log.info "(#{self.object_id}) Connection '#{@addr}' disconnecting"
    log.error $!
  rescue Exception
    @closing = true
    publish(:disconnected)
    unsubscribe_all
    log.error "(#{self.object_id}) Connection#handle_input"
    log.error $!
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
    publish(:logged_out)
    unsubscribe_all
    log.info "(#{self.object_id}) Connection '#{@addr}' disconnecting"
  rescue Exception
    @closing = true
    publish(:disconnected)
    unsubscribe_all
    log.error "(#{self.object_id}) Connection#handle_output"
    log.error $!
  end

  # handle_close is called to when an close event occurs for this session.
  def handle_close
    @connected = false
    publish(:logged_out)
    unsubscribe_all
    log.info "(#{self.object_id}) Connection '#{@addr}' closing"
    @server.unregister(self)
#    @sock.shutdown   # odd errors thrown with this
    @sock.close
  rescue Exception
    log.error "(#{self.object_id}) Connection#handle_close"
    log.error $!
  end

  # handle_oob is called when an out of band data event occurs for this
  # session.
  def handle_oob
    buf = @sockio.read_urgent
    log.debug "(#{self.object_id}) Connection urgent data received - '#{buf[0]}'"
    @pstack.set(:urgent, true)
    buf = @pstack.filter_call(:filter_in,buf)
  rescue Exception
    log.error "(#{self.object_id}) Connection#handle_oob"
    log.error $!
  end

  # This is called from TelnetFilter when we are done with negotiations.
  # The event :initdone wakens observer to begin user activity
  def set_initdone
    @initdone = true
    publish(:initdone)
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
  def update(msg)
    case msg
    when :logged_out
      @closing = true
    when :reconnecting
      unsubscribe_all
      log.info "(#{self.object_id}) Connection '#{@addr}' closing for reconnection"
      @server.unregister(self)
  #    @sock.shutdown   # odd errors thrown with this
      @sock.close
    when String
      sendmsg(msg)
    else
      log.error "(#{self.object_id}) Connection#update - unknown message '#{@msg.inspect}'"
    end
  end

  # [+attrib+] - A Symbol not handled here is assumed to be a query and
  #           its handling is delegated to the ProtocolStack, the result
  #           of which is a pair immediately sent back to as a message
  #           to the client.
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
  def query(attrib)
    @pstack.query(attrib)
  end

  # [+attrib,val+] - An Array not handled here is assumed to be a set command and
  #           its handling is delegated to the ProtocolStack.
  #
  #         <pre>
  #         client -> us
  #             [:color, true]
  #         us     -> ProtocolStack
  #             set(:color, true)
  #         </pre>
  #
  def set(attrib, val)
    @pstack.set(attrib, val)
  end


  # sendmsg places a message on the Connection's output buffer.
  # [+msg+]  The message, a reference to a buffer
  def sendmsg(msg)
    @outbuffer << msg
    @write_blocked = true  # change status to write_blocked
  end

end


#
# file::    filter.rb
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

require 'telnetcodes'
require 'ostruct'

# The Filter class is an abstract class defining the minimal methods
# needed to filter data.
#
# A Filter can keep state and partial data
class Filter

  # Initialize state of filter
  #
  # [+conn+] The connection associated with this filter
  # [+opts+] An optional hash of options
  def initialize(conn, wopts={})
    @conn, @wopts = conn, wopts
  end

  # The filter_in method filters input data
  # [+str+]    The string to be processed
  # [+return+] The filtered data
  def filter_in(str)
    return str
  end

  # The filter_out method filters output data
  # [+str+]    The string to be processed
  # [+return+] The filtered data
  def filter_out(str)
    return str
  end

end

# The TelnetFilter class implements the Telnet protocol.
#
# This implements most of basic Telnet as per RFC 854/855/1143 and
# options in RFC 857/858/1073/1091
#
# todo:: DataMark/Sync
#
class TelnetFilter < Filter
  include TelnetCodes


  # Initialize state of filter
  #
  # [+conn+] The connection associated with this filter
  # [+opts+] An optional hash of options
  def initialize(conn, wopts={})
    @mode = :normal #  Parse mode :normal, :cmd, :cr
    @state = {}
    @sc = nil
    @supp_opts = [ ECHO, SGA, TTYPE, NAWS ]
    @log = conn.server.log
    @ttype = "unknown"
    @twidth = 80
    @theight = 23
    super(conn, wopts)
  end

  # negotiate starting options
  #
  def init
    @wopts.each do |key,val|
      case key
      when SGA, ECHO
        offer_us(key,val)
      else
        ask_him(key,val)
      end
    end
  end

  # The filter_in method filters input data
  # [+str+]    The string to be processed
  # [+return+] The filtered data
  def filter_in(str)
    buf = ""
    return buf if str.nil? || str.empty?
    @sc ? @sc.concat(str) : @sc = StringScanner.new(str)
    while b = @sc.getbyte
      case mode?
      when :cr
        # handle CRLF and CRNUL by swallowing what follows CR and
        # insertion of LF
        buf << LF.chr
        set_mode(:normal)
      when :cmd
        case b[0]
        when IAC
          # IAC escapes IAC
          buf << IAC.chr
          set_mode(:normal)
        when AYT
          @log.debug("(#{@conn.object_id}) AYT sent")
          @conn.sendmsg("TeensyMUD is here.\n")
          set_mode(:normal)
        when AO, IP, GA, NOP, BRK  # not implemented or ignored
          @log.debug("(#{@conn.object_id}) AO, IP, GA, NOP or BRK sent")
          set_mode(:normal)
        when EC
          @log.debug("(#{@conn.object_id}) EC sent")
          buf.slice!(-1)
          set_mode(:normal)
        when EL
          @log.debug("(#{@conn.object_id}) EL sent")
          p = buf.rindex("\n")
          p ? buf.slice!(pos+1..-1) : buf = ""
          set_mode(:normal)
        when DO, DONT, WILL, WONT
          opt = @sc.getbyte
          if opt.nil?
            @sc.peep
            break
          end
          case b[0]
          when WILL
            replies_him(opt[0],true)
          when WONT
            replies_him(opt[0],false)
          when DO
            requests_us(opt[0],true)
          when DONT
            requests_us(opt[0],false)
          end
          set_mode(:normal)
        when SB
          opt = @sc.getbyte
          if opt.nil? || @sc.check_until(/#{IAC.chr}#{SE.chr}/).nil?
            @sc.peep
            break
          end
          data = @sc.scan_until(/#{IAC.chr}#{SE.chr}/).chop.chop
          sub_neg(opt[0],data)
          set_mode(:normal)
        else
          @log.debug("(#{@conn.object_id}) Unknown Telnet command - #{b[0].to_s}")
          set_mode(:normal)
        end
      when :normal
        case b[0]
        when CR
          set_mode(:cr)
        when IAC
          set_mode(:cmd)
        when BS
          buf.slice!(-1)
        else
          buf << b
        end
      end
    end  # while b
    @sc = nil if @sc.eos?
    buf
  end

  # The filter_out method filters output data
  # [+str+]    The string to be processed
  # [+return+] The filtered data
  def filter_out(str)
    buf = ""
    return buf if str.nil? || str.empty?
    # Convert linefeeds to CRLF
    buf = str.gsub(/\n/, "\r\n")
    buf
  end

  def enabled?(opt, who)
    option(opt)
    @state[opt].send(who)
  end

  def supports?(opt)
    @supp_opts.include?(opt)
  end

  def desired?(opt)
    @wopts.include?(opt)
  end

  # Ask the client to enable or disable an option.
  #
  # [+opt+]   The option code
  # [+enable+] true for enable, false for disable
  def ask_him(opt, enable)
    @log.debug("(#{@conn.object_id}) Requested Telnet option #{opt.to_s} set to #{enable.to_s}")
    initiate(opt, enable, :him)
  end

  # Offer the server to enable or disable an option
  #
  # [+opt+]   The option code
  # [+enable+] true for enable, false for disable
  def offer_us(opt, enable)
    @log.debug("(#{@conn.object_id}) Offered Telnet option #{opt.to_s} set to #{enable.to_s}")
    initiate(opt, enable, :us)
  end

private

  def sub_neg(opt,data)
    case opt
    when NAWS
      data.gsub!(/#{IAC}#{IAC}/, IAC.chr) # 255 needs to be undoubled from data
      @twidth = data[0..1].unpack('n')
      @theight = data[2..3].unpack('n')
      @log.debug("(#{@conn.object_id}) Terminal width #{@twidth} / height #{@theight}")
    when TTYPE
      if data[0] = 0
        @ttype = data[1..-1]
        @log.debug("(#{@conn.object_id}) Terminal type - #{@ttype}")
      end
    end
  end

  def mode?
    return @mode
  end

  def set_mode(m)
    @mode = m
  end

  def option(opt)
    return if @state.key?(opt)
    o = OpenStruct.new
    o.us = :no
    o.him = :no
    o.usq = :empty
    o.himq = :empty
    @state[opt] = o
  end

  # Initiate a request to client.  Called by ask_him or offer_us.
  #
  # [+opt+]   The option code
  # [+enable+] true for enable, false for disable
  # [+who+] :him if asking client, :us if server offering
  def initiate(opt, enable, who)
    option(opt)

    case who
    when :him
      willdo = DO.chr
      wontdont = DONT.chr
      whoq = :himq
    when :us
      willdo = WILL.chr
      wontdont = WONT.chr
      whoq = :usq
    else
      # Error
    end

    case @state[opt].send(who)
    when :no
      if enable
        @state[opt].send(who.to_s + "=", :wantyes)
        @conn.sendmsg(IAC.chr + willdo + opt.chr)
      else
        # Error already disabled
        @log.error("(#{@conn.object_id}) Telnet negotiation: option #{opt.to_s} already disabled")
      end
    when :yes
      if enable
        # Error already enabled
        @log.error("(#{@conn.object_id}) Telnet negotiation: option #{opt.to_s} already enabled")
      else
        @state[opt].send(who.to_s + "=", :wantno)
        @conn.sendmsg(IAC.chr + wontdont + opt.chr)
      end
    when :wantno
      if enable
        case @state[opt].send(whoq)
        when :empty
          @state[opt].send(whoq.to_s + "=", :opposite)
        when :opposite
          # Error already queued enable request
          @log.error("(#{@conn.object_id}) Telnet negotiation: option #{opt.to_s} already queued enable request")
        end
      else
        case @state[opt].send(whoq)
        when :empty
          # Error already negotiating for disable
          @log.error("(#{@conn.object_id}) Telnet negotiation: option #{opt.to_s} already negotiating for disable")
        when :opposite
          @state[opt].send(whoq.to_s + "=", :empty)
        end
      end
    when :wantyes
      if enable
        case @state[opt].send(whoq)
        when :empty
          #Error already negotiating for enable
          @log.error("(#{@conn.object_id}) Telnet negotiation: option #{opt.to_s} already negotiating for enable")
        when :opposite
          @state[opt].send(whoq.to_s + "=", :empty)
        end
      else
        case @state[opt].send(whoq)
        when :empty
          @state[opt].send(whoq.to_s + "=", :opposite)
        when :opposite
          #Error already queued for disable request
          @log.error("(#{@conn.object_id}) Telnet negotiation: option #{opt.to_s} already queued for disable request")
        end
      end
    end
  end

  # Client replies WILL or WONT
  #
  # [+opt+]   The option code
  # [+enable+] true for WILL answer, false for WONT answer
  def replies_him(opt, enable)
    @log.debug("(#{@conn.object_id}) Client replies to Telnet option #{opt.to_s} set to #{enable.to_s}")
    response(opt, enable, :him)
  end

  # Client requests DO or DONT
  #
  # [+opt+]   The option code
  # [+enable+] true for DO request, false for DONT request
  def requests_us(opt, enable)
    @log.debug("(#{@conn.object_id}) Client requests Telnet option #{opt.to_s} set to #{enable.to_s}")
    response(opt, enable, :us)
  end

  # Handle client response.  Called by requests_us or replies_him
  #
  # [+opt+]   The option code
  # [+enable+] true for WILL answer, false for WONT answer
  # [+who+] :him if client replies, :us if client requests
  def response(opt, enable, who)
    option(opt)

    case who
    when :him
      willdo = DO.chr
      wontdont = DONT.chr
      whoq = :himq
    when :us
      willdo = WILL.chr
      wontdont = WONT.chr
      whoq = :usq
    else
      # Error
    end

    case @state[opt].send(who)
    when :no
      if enable
        if supports?(opt)
        # If we agree
          @state[opt].send(who.to_s + "=", :yes)
          @conn.sendmsg(IAC.chr + willdo + opt.chr)
          @log.debug("(#{@conn.object_id}) Telnet negotiation: agreed to enable option #{opt.to_s}")
        else
        # If we disagree
          @conn.sendmsg(IAC.chr + wontdont + opt.chr)
          @log.debug("(#{@conn.object_id}) Telnet negotiation: disagreed to enable option #{opt.to_s}")
        end
      else
        # Ignore
      end
    when :yes
      if enable
        # Ignore
      else
        @state[opt].send(who.to_s + "=", :no)
        @conn.sendmsg(IAC.chr + wontdont + opt.chr)
      end
    when :wantno
      if enable
        case @state[opt].send(whoq)
        when :empty
          #Error DONT/WONT answered by WILL/DO
          @state[opt].send(who.to_s + "=", :no)
        when :opposite
          #Error DONT/WONT answered by WILL/DO
          @state[opt].send(who.to_s + "=", :yes)
          @state[opt].send(whoq.to_s + "=", :empty)
        end
        @log.error("(#{@conn.object_id}) Telnet negotiation: option #{opt.to_s} DONT/WONT answered by WILL/DO")
      else
        case @state[opt].send(whoq)
        when :empty
          @state[opt].send(who.to_s + "=", :no)
        when :opposite
          @state[opt].send(who.to_s + "=", :wantyes)
          @state[opt].send(whoq.to_s + "=", :empty)
          @conn.sendmsg(IAC.chr + willdo + opt.chr)
        end
      end
    when :wantyes
      if enable
        case @state[opt].send(whoq)
        when :empty
          @state[opt].send(who.to_s + "=", :yes)
        when :opposite
          @state[opt].send(who.to_s + "=", :wantno)
          @state[opt].send(whoq.to_s + "=", :empty)
          @conn.sendmsg(IAC.chr + wontdont + opt.chr)
        end
      else
        case @state[opt].send(whoq)
        when :empty
          @state[opt].send(who.to_s + "=", :no)
        when :opposite
          @state[opt].send(who.to_s + "=", :no)
          @state[opt].send(whoq.to_s + "=", :empty)
        end
      end
    end
  end

end

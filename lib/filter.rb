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
require 'ostruct'
require 'pp'

require 'bbcode'
require 'telnetcodes'

# The Filter class is an abstract class defining the minimal methods
# needed to filter data.
#
# A Filter can keep state and partial data
class Filter

  # Construct filter
  #
  # [+conn+] The connection associated with this filter
  def initialize(conn)
    @conn = conn
    @log = conn.server.log
  end

  # Run any post-contruction initialization
  # [+args+] Optional initial options
  def init(args=nil)
    true
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

  # The filter_query method returns state information for the filter.
  # [+attr+]    A symbol representing the attribute being queried.
  # [+return+] An attr/value pair or false if not defined in this filter
  def filter_query(attr)
    false
  end


  # The filter_set method sets state information on the filter.
  # [+pair+]   An attr/value pair [:symbol, value]
  # [+return+] true if attr not defined in this filter, false if not
  def filter_set(pair)
    false
  end

end

# The TelnetFilter class implements the Telnet protocol.
#
# This implements most of basic Telnet as per RFC 854/855/1143 and
# options in RFC 857/858/1073/1091
#
class TelnetFilter < Filter
  include TelnetCodes
  attr_accessor :hide

  # Initialize state of filter
  #
  # [+conn+] The connection associated with this filter
  # [+opts+] An optional hash of desired initial options
  def initialize(conn, wopts={})
    @wopts = wopts
    @mode = :normal #  Parse mode :normal, :cmd, :cr
    @state = {}
    @sc = nil
    @supp_opts = [ TTYPE, ECHO, SGA, NAWS, BINARY, ZMP ] # supported options
    @sneg_opts = [ TTYPE, ZMP ]  # supported options which imply an initial
    @ttype = []
    @terminal = nil
    @twidth = 80
    @theight = 23
    @hide = false     # if true and server echo set, we echo back asterixes
    @init_tries = 0   # Number of tries at negotitating sub options
    @synch = false
    @urgent = false
    super(conn)
  end

  # Negotiate starting wanted options
  #
  # [+args+] Optional initial options
  def init(args)
    # severl sorts of options here - server offer, ask client or both
    @wopts.each do |key,val|
      case key
      when ECHO, SGA, BINARY, ZMP
        offer_us(key,val)
      else
        ask_him(key,val)
      end
    end
    true
  end

  # The filter_in method filters input data
  # [+str+]    The string to be processed
  # [+return+] The filtered data
  def filter_in(str)
    init_subneg
    buf = ""
    return buf if str.nil? || str.empty?

    @sc ? @sc.concat(str) : @sc = StringScanner.new(str)
    while b = @sc.get_byte

      # OOB sync data
      if @urgent || b[0] == DM
        @log.debug("(#{@conn.object_id}) Sync mode on")
        @urgent = false
        @synch = true
        break
      end

      case mode?
      when :normal
        case b[0]
        when CR
          next if @synch
          set_mode(:cr) if !enabled?(BINARY, :us)
        when IAC
          set_mode(:cmd)
        when BS
          next if @synch
          buf.slice!(-1)
          echo(BS.chr)
        when NUL  # ignore NULs in stream when in normal mode
          next if @synch
          if enabled?(BINARY, :us)
            buf << b
            echo(b)
          else
            @log.debug("(#{@conn.object_id}) unhandled NUL found in stream #{@sc.string}")
          end
        else
          next if @synch
          buf << b
          echo(b)
        end
      when :cr
        # handle CRLF and CRNUL by swallowing what follows CR and
        # insertion of LF
        if !@synch
          buf << LF.chr
          echo(CR.chr + LF.chr)
        end
        set_mode(:normal)
      when :cmd
        case b[0]
        when IAC
          # IAC escapes IAC
          buf << IAC.chr
          set_mode(:normal)
        when AYT
          @log.debug("(#{@conn.object_id}) AYT sent - Msg returned")
          @conn.sock.send("TeensyMUD is here.\n",0)
          set_mode(:normal)
        when AO
          @log.debug("(#{@conn.object_id}) AO sent - Synch returned")
          @conn.sockio.write_flush
          @conn.sock.send(IAC.chr + DM.chr, 0)
          @conn.sockio.write_urgent(DM.chr)
          set_mode(:normal)
        when IP
          @conn.sockio.read_flush
          @conn.sockio.write_flush
          @log.debug("(#{@conn.object_id}) IP sent")
          set_mode(:normal)
        when GA, NOP, BRK  # not implemented or ignored
          @log.debug("(#{@conn.object_id}) GA, NOP or BRK sent")
          set_mode(:normal)
        when DM
          @log.debug("(#{@conn.object_id}) Synch mode off")
          @synch = false
          set_mode(:normal)
        when EC
          next if @synch
          @log.debug("(#{@conn.object_id}) EC sent")
          buf.slice!(-1)
          set_mode(:normal)
        when EL
          next if @synch
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
          parse_subneg(opt[0],data)
          set_mode(:normal)
        else
          @log.debug("(#{@conn.object_id}) Unknown Telnet command - #{b[0]}")
          set_mode(:normal)
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

    if !enabled?(BINARY, :us)
      buf = str.gsub(/\n/, "\r\n")
    end
    buf
  end

  # The filter_query method returns state information for the filter.
  # [+attr+]    A symbol representing the attribute being queried.
  # [+return+] An attr/value pair or nil if not defined in this filter
  def filter_query(attr)
    case attr
    when :terminal
      return [:terminal, @terminal]
    when :termsize
      return [:termsize, [@twidth, @theight]]
    end
    false
  end

  # The filter_set method sets state information on the filter.
  # [+pair+]   An attr/value pair [:symbol, value]
  # [+return+] true or false if attr not defined in this filter
  def filter_set(pair)
    case pair[0]
    when :urgent
      @urgent = pair[1]
      true
    when :hide
      @hide = pair[1]
      true
    when :init_subneg
      init_subneg
      true
    else
      false
    end
  end

  ###### Custom public methods

  # Test to see if option is enabled
  # [+opt+] The Telnet option code
  # [+who+] The side to check :us or :him
  def enabled?(opt, who)
    option(opt)
    e = @state[opt].send(who)
    e == :yes ? true : false
  end

  # Test to see if option is supported
  # [+opt+] The Telnet option code
  # [+who+] The side to check :us or :him
  def supports?(opt)
    @supp_opts.include?(opt)
  end

  # Test to see which state we prefer this option to be in
  # [+opt+] The Telnet option code
  def desired?(opt)
    st = @wopts[opt]
    st = false if st.nil?
    st
  end

  # Handle server-side echo
  def echo(ch)
    if enabled?(ECHO, :us)
      if @hide && ch[0] != CR
        @conn.sock.send('*',0)
      else
        @conn.sock.send(ch,0)
      end
    end
  end

  # Negotiate starting wanted options that imply subnegotation
  # So far only terminal type
  def init_subneg
    return if @sneg_opts.empty?

    @init_tries += 1

    @wopts.each_key do |opt|
      next if !@sneg_opts.include?(opt)
      case opt
      when TTYPE
        who = :him
      else
        who = :us
      end
      if desired?(opt) == enabled?(opt, who)
        case opt
        when TTYPE
          @conn.sendmsg(IAC.chr + SB.chr + TTYPE.chr + 1.chr + IAC.chr + SE.chr)
        when ZMP
          @log.info("(#{@conn.object_id}) ZMP successfully negotiated." )
          @conn.sendmsg("#{IAC.chr}#{SB.chr}#{ZMP.chr}" +
            "zmp.check#{NUL.chr}color.#{NUL.chr}" +
            "#{IAC.chr}#{SE.chr}")
          @conn.sendmsg("#{IAC.chr}#{SB.chr}#{ZMP.chr}" +
            "zmp.ident#{NUL.chr}TeensyMUD#{NUL.chr}#{Version}#{NUL.chr}A sexy mud server#{NUL.chr}" +
            "#{IAC.chr}#{SE.chr}")
          @conn.sendmsg("#{IAC.chr}#{SB.chr}#{ZMP.chr}" +
            "zmp.time#{NUL.chr}#{Time.now.utc.strftime("%Y-%m-%d %H:%M:%S")}#{NUL.chr}" +
            "#{IAC.chr}#{SE.chr}")
          @conn.sendmsg("#{IAC.chr}#{SB.chr}#{ZMP.chr}" +
            "zmp.input#{NUL.chr}\n     I see you support...\n     ZMP protocol\n{NUL.chr}" +
            "#{IAC.chr}#{SE.chr}")
        end
        @sneg_opts.delete(opt)
      end
    end

    if @init_tries > 15
      @log.debug("(#{@conn.object_id}) Telnet init_subneg option - Timed out after #{@init_tries} tries.")
    end
    if @sneg_opts.empty? || @init_tries > 15
      @sneg_opts = []
      @conn.set_initdone
    else

    end
  end

private
  ###### Private methods

  # parse the subnegotiation data and save it
  # [+opt+] The Telnet option found
  # [+data+] The data found between SB OPTION and IAC SE
  def parse_subneg(opt,data)
    case opt
    when NAWS
      data.gsub!(/#{IAC}#{IAC}/, IAC.chr) # 255 needs to be undoubled from data
      @twidth = data[0..1].unpack('n')
      @theight = data[2..3].unpack('n')
      @log.debug("(#{@conn.object_id}) Terminal width #{@twidth} / height #{@theight}")
    when TTYPE
      if data[0] = 0
        if !@ttype.include?(data[1..-1])
          @log.debug("(#{@conn.object_id}) Terminal type - #{data[1..-1]}")
          # short-circuit choice because of Windows telnet client
          if data[1..-1].downcase == 'vt100'
            @ttype << data[1..-1]
            @terminal = 'vt100'
            @log.debug("(#{@conn.object_id}) Terminal choice - #{@terminal} in list #{@ttype.inspect}")
          end
          return if @terminal
          @ttype << data[1..-1]
          @conn.sendmsg(IAC.chr + SB.chr + TTYPE.chr + 1.chr + IAC.chr + SE.chr)
        else
          return if @terminal
          choose_terminal
        end
      end
    when ZMP
      data.gsub!(/#{IAC}#{IAC}/, IAC.chr) # 255 needs to be undoubled from data
      args = data.split("\0")
      cmd = args.shift
      handle_zmp(cmd,args)
    end
  end

  # Pick a preferred terminal
  # Order is vt100, vt999, ansi, xterm, or a recognized custom client
  # Should not pick vtnt as we dont handle it
  def choose_terminal
    if @ttype.empty?
      @terminal = "dumb"
    end

    @terminal = @ttype.find {|t| t =~  /(vt|VT)[-]?100/ } if !@terminal
    @terminal = @ttype.find {|t| t =~ /(vt|VT)[-]?\d+/ } if !@terminal
    @terminal = @ttype.find {|t| t =~ /(ansi|ANSI).*/ } if !@terminal
    @terminal = @ttype.find {|t| t =~ /(xterm|XTERM).*/ } if !@terminal
    @terminal = @ttype.find {|t| t =~ /mushclient/ } if !@terminal

    if @terminal && @ttype.last != @terminal # short circuit retraversal of options
      @ttype.each do |t|
        @conn.sendmsg(IAC.chr + SB.chr + TTYPE.chr + 1.chr + IAC.chr + SE.chr)
        break if t == @terminal
      end
    elsif @ttype.last != @terminal
      @terminal = 'dumb'
    end

    @log.debug("(#{@conn.object_id}) Terminal choice - #{@terminal} in list #{@ttype.inspect}")
  end

  # Get current parse mode
  # [+return+] The current parse mode
  def mode?
    return @mode
  end

  # set current parse mode
  # [+m+] Mode to set it to
  def set_mode(m)
    @mode = m
  end

  # Creates an option entry in our state table and sets its initial state
  def option(opt)
    return if @state.key?(opt)
    o = OpenStruct.new
    o.us = :no
    o.him = :no
    o.usq = :empty
    o.himq = :empty
    @state[opt] = o
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
        @state[opt].send("#{who}=", :wantyes)
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
        @state[opt].send("#{who}=", :wantno)
        @conn.sendmsg(IAC.chr + wontdont + opt.chr)
      end
    when :wantno
      if enable
        case @state[opt].send(whoq)
        when :empty
          @state[opt].send("#{whoq}=", :opposite)
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
          @state[opt].send("#{whoq}=", :empty)
        end
      end
    when :wantyes
      if enable
        case @state[opt].send(whoq)
        when :empty
          #Error already negotiating for enable
          @log.error("(#{@conn.object_id}) Telnet negotiation: option #{opt.to_s} already negotiating for enable")
        when :opposite
          @state[opt].send("#{whoq}=", :empty)
        end
      else
        case @state[opt].send(whoq)
        when :empty
          @state[opt].send("#{whoq}=", :opposite)
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
        if desired?(opt)
        # If we agree
          @state[opt].send("#{who}=", :yes)
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
        @state[opt].send("#{who}=", :no)
        @conn.sendmsg(IAC.chr + wontdont + opt.chr)
      end
    when :wantno
      if enable
        case @state[opt].send(whoq)
        when :empty
          #Error DONT/WONT answered by WILL/DO
          @state[opt].send("#{who}=", :no)
        when :opposite
          #Error DONT/WONT answered by WILL/DO
          @state[opt].send("#{who}=", :yes)
          @state[opt].send("#{whoq}=", :empty)
        end
        @log.error("(#{@conn.object_id}) Telnet negotiation: option #{opt.to_s} DONT/WONT answered by WILL/DO")
      else
        case @state[opt].send(whoq)
        when :empty
          @state[opt].send("#{who}=", :no)
        when :opposite
          @state[opt].send("#{who}=", :wantyes)
          @state[opt].send("#{whoq}=", :empty)
          @conn.sendmsg(IAC.chr + willdo + opt.chr)
        end
      end
    when :wantyes
      if enable
        case @state[opt].send(whoq)
        when :empty
          @state[opt].send("#{who}=", :yes)
        when :opposite
          @state[opt].send("#{who}=", :wantno)
          @state[opt].send("#{whoq}=", :empty)
          @conn.sendmsg(IAC.chr + wontdont + opt.chr)
        end
      else
        case @state[opt].send(whoq)
        when :empty
          @state[opt].send("#{who}=", :no)
        when :opposite
          @state[opt].send("#{who}=", :no)
          @state[opt].send("#{whoq}=", :empty)
        end
      end
    end
  end

  def handle_zmp(cmd,args)
    @log.info("(#{@conn.object_id}) ZMP command recieved - '#{cmd}' args: #{args.inspect}" )
    case cmd
    when "zmp.ping"
      @conn.sendmsg("#{IAC.chr}#{SB.chr}#{ZMP.chr}" +
        "zmp.time#{NUL.chr}#{Time.now.utc.strftime("%Y-%m-%d %H:%M:%S")}#{NUL.chr}" +
        "#{IAC.chr}#{SE.chr}")
    when "zmp.time"
    when "zmp.ident"
      # simply return the favor
      @conn.sendmsg("#{IAC.chr}#{SB.chr}#{ZMP.chr}" +
        "zmp.ident#{NUL.chr}TeensyMUD#{NUL.chr}#{Version}#{NUL.chr}A sexy mud server#{NUL.chr}" +
        "#{IAC.chr}#{SE.chr}")
    when "zmp.check"
      # We support nothing yet so we'll echo back nay on whatever they requested
      @conn.sendmsg("#{IAC.chr}#{SB.chr}#{ZMP.chr}" +
        "zmp.no-support#{NUL.chr}args[0]{NUL.chr}" +
        "#{IAC.chr}#{SE.chr}")
    when "zmp.support"
    when "zmp.no-support"
    when "zmp.input"
      # Now we just simply pass this whole load to the Player.parse
      # WARN: This means there is a possibility of out-of-order processing of @inbuffer
      @conn.message(args[0])
    end
  end

end

# The ColorFilter class implements ANSI color (SGR) support.
#
# A Filter can keep state and partial data
class ColorFilter < Filter

  # Construct filter
  #
  # [+conn+] The connection associated with this filter
  # [+wopts+] An optional hash of desired initial options
  def initialize(conn)
    @color = false
    super(conn)
  end

  # The filter_out method filters output data
  # [+str+]    The string to be processed
  # [+return+] The filtered data
  def filter_out(str)
    if @color
      s = BBCode.bbcode_to_ansi(str)
    else
      s = BBCode.strip_bbcode(str)
    end
    return s
  end

  # The filter_query method returns state information for the filter.
  # [+attr+]    A symbol representing the attribute being queried.
  # [+return+] An attr/value pair or false if not defined in this filter
  def filter_query(attr)
    case attr
    when :color
      return [:color, @color]
    end
    false
  end

  # The filter_set method sets state information on the filter.
  # [+pair+]   An attr/value pair [:symbol, value]
  # [+return+] true if attr not defined in this filter, false if not
  def filter_set(pair)
    case pair[0]
    when :color
      @color = pair[1]
      true
    else
      false
    end
  end

end



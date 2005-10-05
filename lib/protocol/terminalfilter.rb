#
# file::    terminalfilter.rb
# author::  Jon A. Lambert
# version:: 2.6.0
# date::    10/04/2005
#
# This source code copyright (C) 2005 by Jon A. Lambert
# All rights reserved.
#
# Released under the terms of the TeensyMUD Public License
# See LICENSE file for additional information.
#

require 'protocol/filter'
require 'protocol/asciicodes'
require 'protocol/vt100codes'

# The TerminalFilter class implements a subset of ANSI/VT100 protocol.
#
class TerminalFilter < Filter
  include ASCIICodes
  include VT100Codes

  # Construct filter
  #
  # [+pstack+] The ProtocolStack associated with this filter
  def initialize(pstack)
    super(pstack)
    @mode = :normal #  Parse mode :normal, :escape
    @csi = ""
  end

  # Run any post-contruction initialization
  # [+args+] Optional initial options
  def init(args=nil)
    true
  end

  # The filter_in method filters out VTxx terminal data and inserts format
  # strings into the input stream.
  # [+str+]    The string to be processed
  # [+return+] The filtered data
  def filter_in(str)
    buf = ""

    str.each_byte do |b|
      case mode?
      when :normal
        case b
        when BS, DEL
          @pstack.log.debug("(#{@pstack.conn.object_id}) BS, DEL found")
          if buf.size > 1
            buf.slice!(-1)
          elsif @pstack.conn.inbuffer.size > 0
            @pstack.conn.inbuffer.slice!(-1)
          end
        when TAB
          @pstack.log.debug("(#{@pstack.conn.object_id}) TAB found")
          buf << "[TAB]"
        when BEL
          buf << "[BELL]"
        when ESC
          @pstack.log.debug("(#{@pstack.conn.object_id}) ESC found")
          set_mode :escape
        else
          buf << b.chr
        end
      when :escape
        case b
        when ?[
          @csi = ""
          @pstack.log.debug("(#{@pstack.conn.object_id}) CSI sequence found")
          set_mode :csi
        when ?O
          set_mode :ss3
        when ?D
          buf << "[SCROLL DOWN]"
          set_mode :normal
        when ?U
          buf << "[SCROLL UP]"
          set_mode :normal
        else
          set_mode :normal
        end
      when :csi
        case b
        when ?A
          i = @csi.to_i
          i = 1 if i == 0
          @csi = ""
          buf << "[UP #{i}]"
          set_mode :normal
        when ?B
          i = @csi.to_i
          i = 1 if i == 0
          @csi = ""
          buf << "[DOWN #{i}]"
          set_mode :normal
        when ?C
          i = @csi.to_i
          i = 1 if i == 0
          @csi = ""
          buf << "[RIGHT #{i}]"
          set_mode :normal
        when ?D
          i = @csi.to_i
          i = 1 if i == 0
          @csi = ""
          buf << "[LEFT #{i}]"
          set_mode :normal
        when ?H, ?f
          a = @csi.split(";")
          @csi = ""
          a = ["0","0"] if a.empty?
          buf << "[HOME #{a[0]},#{a[1]}]"
          set_mode :normal
        when ?R # report cursor pos
          a = @csi.split(";")
          @csi = ""
          a = ["0","0"] if a.empty?
          buf << "[CURSOR #{a[0]},#{a[1]}]"
          set_mode :normal
        when ?J, ?K, ?g, ?c, ?h, ?l, ?s, ?u
          @csi = ""
          # unhandled
          set_mode :normal
        when ?n
          i = @csi.to_i
          @csi = ""
          if i == 6
            # request for report cursor pos
            buf << "[CURSOR REPORT]"
          end
          set_mode :normal
        when ?m  # color
          a = @csi.split(";")
          @csi = ""
          a.each do |cd|
            s = SGR2CODE[cd]
            buf << s if s
          end
          set_mode :normal
        when ?~  # keys
          i = @csi.to_i
          @csi = ""
          case i
          when 1, 7
            buf << "[HOME 0,0]"
          when 2
            buf << "[INS]"
          when 3  # delete
            @pstack.log.debug("(#{@pstack.conn.object_id}) BS, DEL found")
            if buf.size > 1
              buf.slice!(-1)
              echo("\010")
            elsif @pstack.conn.inbuffer.size > 0
              @pstack.conn.inbuffer.slice!(-1)
              echo("\010")
            end
          when 4, 8
            buf << "[END]"
          when 5
            buf << "[PAGEUP]"
          when 6
            buf << "[PAGEDOWN]"
          when 11
            buf << "[F1]"
          when 12
            buf << "[F2]"
          when 13
            buf << "[F3]"
          when 14
            buf << "[F4]"
          when 15
            buf << "[F5]"
          when 17
            buf << "[F6]"
          when 18
            buf << "[F7]"
          when 19
            buf << "[F8]"
          when 20
            buf << "[F9]"
          when 21
            buf << "[F10]"
          end
          set_mode :normal
        else
          @csi << b.chr
        end
      when :ss3
        case b
        when ?P
          buf << "[F1]"
        when ?Q
          buf << "[F2]"
        when ?R
          buf << "[F3]"
        when ?S
          buf << "[F4]"
        end
        set_mode :normal
      end
    end  # eachwhile b

    buf
  end

  # The filter_out method filters output data
  # [+str+]    The string to be processed
  # [+return+] The filtered data
  def filter_out(str)
    str
  end

  # Handle server-side echo
  def echo(ch)
    if @pstack.echo_on
      if @pstack.hide_on && ch[0] != CR
        @pstack.conn.sock.send('*',0)
      else
        @pstack.conn.sock.send(ch,0)
      end
    end
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

end


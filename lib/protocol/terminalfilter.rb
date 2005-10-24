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
    @mode = :ground #  Parse mode :ground, :escape
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
      when :ground
        case b
        when 0x20..0x7e
          buf << b.chr
        when ESC
          @pstack.log.debug("(#{@pstack.conn.object_id}) ESC found")
          @collect = ""
          set_mode :escape
        # These cause immediate execution no matter what mode
        when ENQ, BEL, BS, TAB, VT, FF, SO, SI, DC1, DC3, CAN, SUB, DEL
          case b
          when BS, DEL
            @pstack.log.debug("(#{@pstack.conn.object_id}) BS, DEL found")
            # slice local buffer or connection buffer
            buf.slice!(-1) || @pstack.conn.inbuffer.slice!(-1)
          when CAN, SUB
            @collect = ""
            set_mode :ground
          else
            buf << execute(b)
          end
        else
          buf << b.chr
        end
      when :escape
        case b
        when ?[
          @pstack.log.debug("(#{@pstack.conn.object_id}) CSI sequence found")
          set_mode :csi
        when ?]
          @pstack.log.debug("(#{@pstack.conn.object_id}) OSC/XTERM sequence found")
          set_mode :xterm
        when ?P
          @pstack.log.debug("(#{@pstack.conn.object_id}) DCS sequence found")
          set_mode :dcs
        when ?O
          @pstack.log.debug("(#{@pstack.conn.object_id}) SS3 sequence found")
          set_mode :ss3
        when ?X, ?^, ?_
          @pstack.log.debug("(#{@pstack.conn.object_id}) SOS/PM/APC sequence found")
          set_mode :sospmapc
        when ?D
          buf << "[SCROLL DOWN]"
          set_mode :ground
        when ?M
          buf << "[SCROLL UP]"
          set_mode :ground
        # VT52
        when ?A
          buf << "[UP 1]"
          set_mode :ground
        when ?B
          buf << "[DOWN 1]"
          set_mode :ground
        when ?C
          buf << "[RIGHT 1]"
          set_mode :ground
        when ?D
          buf << "[LEFT 1]"
          set_mode :ground
        # /VT52
#        when ?H # Set tab at current position - ignored
#        when ?E # Next line - like CRLF?
#        when ?7 # Save cursor and attributes
#        when ?8 # Restore cursor and attributes
#        when ?c # reset device
        # These cause immediate execution no matter what mode
        when ENQ, BEL, BS, TAB, VT, FF, SO, SI, DC1, DC3, CAN, SUB, DEL
          case b
          when BS, DEL
            @pstack.log.debug("(#{@pstack.conn.object_id}) BS, DEL found")
            # slice local buffer or connection buffer
            buf.slice!(-1) || @pstack.conn.inbuffer.slice!(-1)
          when CAN, SUB
            @collect = ""
            set_mode :ground
          else
            buf << execute(b)
          end
        when 0x20..0x2F  # " !"#$%&'()*+,-./"
          @collect << b.chr
          set_mode :escint
        else
# These should all be immediately dispatched and sent to ground mode
#        when "0123456789:;<=>?@ABCDEFGHIJKLMNO" 0x30..0x4F
#        when "QRSTUVW" 0x51..0x57
#        when "YZ" 0x59..0x5A
#        when "\\" 0x5C
#        when "`abcdefghijklmnopqrstuvwxyz{|}~" 0x60..0x7e
          set_mode :ground
        end
      when :escint
#        case b
#        when ?( # Set default font
#        when ?) # Set alternate font
           # both ( and ) may be followed by A,B,0,1,2  !!
#        end
         set_mode :ground
      when :dcs
         set_mode :ground
      when :xterm
         set_mode :ground
      when :sospmapc
         set_mode :ground
      when :csi
        case b
        when ?A
          buf << "[UP #{@collect.to_i == 0 ? 1 : @collect.to_i}]"
          set_mode :ground
        when ?B
          buf << "[DOWN #{@collect.to_i == 0 ? 1 : @collect.to_i}]"
          set_mode :ground
        when ?C
          buf << "[RIGHT #{@collect.to_i == 0 ? 1 : @collect.to_i}]"
          set_mode :ground
        when ?D
          buf << "[LEFT #{@collect.to_i == 0 ? 1 : @collect.to_i}]"
          set_mode :ground
        when ?H, ?f  # set cursor position
          a = @collect.split(";")
          a = ["0","0"] if a.empty?
          buf << "[HOME #{a[0]},#{a[1]}]"
          set_mode :ground
        when ?R # report cursor pos
          a = @collect.split(";")
          a = ["0","0"] if a.empty?
          buf << "[CURSOR #{a[0]},#{a[1]}]"
          set_mode :ground
        when ?r # Set scrolling region
          a = @collect.split(";")
          a = ["1","1"] if a.empty?  # lines numbered from 1
                 # This should be 1 to n or the whole screen if no parms
          buf << "[SREGION #{a[0]},#{a[1]}]"
          set_mode :ground
        when ?J, ?K, ?g, ?c, ?h, ?l, ?s, ?u, ?x, ?y, ?q, ?i, ?p
          # unhandled
          set_mode :ground
#        when ?c  DA request/response
#        when ?J  Erase display
#     Erase from cursor to end of screen         Esc [ 0 J    or Esc [ J
#     Erase from beginning of screen to cursor   Esc [ 1 J
#     Erase entire screen                        Esc [ 2 J

#        when ?K  Erase line
#     Erase from cursor to end of line           Esc [ 0 K    or Esc [ K
#     Erase from beginning of line to cursor     Esc [ 1 K
#     Erase line containing cursor               Esc [ 2 K

#        when ?g  Tab clear at current position
#  CSI 3 g is clear all tabs

#        when ?h  Set mode
#        when ?l  Reset mode
# Enable Line Wrap  <ESC>[7h
# Disable Line Wrap <ESC>[7l

#        when ?s  save cursor
#        when ?u  unsave cursor
#  Same as ESC7 and ESC8

#        when ?x  Report terminal parameters
#        when ?y  Confidence test
#        when ?q  load LEDs
#        when ?i  printing
#        when ?p  Set Key Definition  <ESC>[{key};"{string}"p

#        when ?P # -> set_mode :dcs

        when ?n  # Device status request
          i = @collect.to_i
          if i == 6
            # request for report cursor pos
            buf << "[CURSOR REPORT]"
          end
          set_mode :ground
        when ?m  # SGR color
          a = @collect.split(";")
          a.each do |cd|
            s = SGR2CODE[cd]
            buf << s if s
          end
          set_mode :ground
        when ?~  # keys
          i = @collect.to_i
          case i
          when 1, 7
            buf << "[HOME 0,0]"
          when 2
            buf << "[INS]"
          when 3  # delete
            @pstack.log.debug("(#{@pstack.conn.object_id}) BS, DEL found")
            buf.slice!(-1) || @pstack.conn.inbuffer.slice!(-1)
            echo(BS.chr)
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
          set_mode :ground
        # These cause immediate execution no matter what mode
        when ENQ, BEL, BS, TAB, VT, FF, SO, SI, DC1, DC3, CAN, SUB, DEL
          case b
          when BS, DEL
            @pstack.log.debug("(#{@pstack.conn.object_id}) BS, DEL found")
            # slice local buffer or connection buffer
            buf.slice!(-1) || @pstack.conn.inbuffer.slice!(-1)
          when CAN, SUB
            @collect = ""
            set_mode :ground
          else
            buf << execute(b)
          end
        else
          @collect << b.chr
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
        # ANSI cursor key mode
        when ?A
          buf << "[UP 1]"
        when ?B
          buf << "[DOWN 1]"
        when ?C
          buf << "[RIGHT 1]"
        when ?D
          buf << "[LEFT 1]"
        # /ANSI cursor key mode
        # These cause immediate execution no matter what mode
        when ENQ, BEL, BS, TAB, VT, FF, SO, SI, DC1, DC3, CAN, SUB, DEL
          case b
          when BS, DEL
            @pstack.log.debug("(#{@pstack.conn.object_id}) BS, DEL found")
            # slice local buffer or connection buffer
            buf.slice!(-1) || @pstack.conn.inbuffer.slice!(-1)
          when CAN, SUB
            @collect = ""
            set_mode :ground
          else
            buf << execute(b)
          end
        end
        set_mode :ground
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

  def execute(b)
    case b
    when ENQ, SO, SI, DC1, DC3 # not handled
# ENQ  Transmit ANSWERBACK message
# SO   Switch to G1 character set
# SI   Switch to G0 character set
# DC1  Causes terminal to resume transmission (XON).
# DC3  Causes terminal to stop transmitting all codes except XOFF and XON (XOFF).
    when VT, FF
      "[UP 1]"
    when TAB
      @pstack.log.debug("(#{@pstack.conn.object_id}) TAB found")
      "[TAB]"
    when BEL
      "[BELL]"
    else
      ""
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


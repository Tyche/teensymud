#!/usr/bin/ruby
#
# file::    tclient.rb
# author::  Jon A. Lambert
# version:: 2.5.4
# date::    09/23/2005
#
# This source code copyright (C) 2005 by Jon A. Lambert
# All rights reserved.
#
# Released under the terms of the TeensyMUD Public License
# See LICENSE file for additional information.
#

require 'pp'

$:.unshift "lib"
$:.unshift "vendor"

require 'net'

Version = "0.1.0"
BANNER=<<-EOH

          This is TeensyClient version #{Version}

          Copyright (C) 2005 by Jon A. Lambert
 Released under the terms of the TeensyMUD Public License

EOH

#
# =Purpose
# TeensyClient is a really cheap mud client
#



#
class Client
  include Observable

  def initialize(opts)
    @opts = opts
  end

  def message(msg)
    changed
    notify_observers(msg)
  end

  def update(msg)
    case msg
    when Connection
      delete_observers
      msg.add_observer(self)
      self.add_observer(msg)
      if @opts.win32
        message([:terminal, "vt100"])
      else
        message([:terminal, "xterm"])
      end
    when :initdone
      message([:termsize, [80,43]])
    end
  end

end

class CursesClient < Client
  def initialize(opts)
    super(opts)
    Curses.init_screen
    Curses.cbreak
    Curses.noecho if @opts.echo
    Curses.nl
    Curses.stdscr.keypad(true)
    Curses.stdscr.scrollok(true)
    Curses.timeout = 0
    Curses.start_color
  end

  def conmsg msg
    Curses.addstr(msg)
    Curses.refresh
  end

  def update(msg)
    case msg
    when Connection, :initdone
      super(msg)
    when :logged_out, :disconnected
      delete_observers
      $shutdown = true
      Curses.addstr "Disconnected."
      exit
    when String
      Curses.addstr(msg)
      Curses.refresh
    else
      Curses.addstr "Unknown msg - #{msg.inspect}"
    end
  end

  def run
    shutdown = false
    connection = Reactor.new(@opts.port, $connopts, @opts.address)
    raise "Unable to start TeensyClient" unless connection.start(self)
    conmsg "Connected to #{@opts.address}:#{@opts.port}.  Use F10 to QUIT"
    until shutdown
      connection.poll(0.1)
      Curses.refresh
      c = Curses.getch
      case c
      when 32..127
        message(c.chr)
      when Curses::KEY_ENTER
        message("\r\n")
      when 10
        message("\n")
      when 4294967295 # Error Timeout. This is -1 in Bignum format
      when Curses::KEY_F10
        conmsg "Quitting..."
        shutdown = true
      else
        conmsg "Unknown key hit code - #{c.inspect}"
      end
    end # until
    connection.stop
  rescue SystemExit, Interrupt
    conmsg "\nConnection closed exiting"
  rescue Exception
    conmsg "\nException caught error in client: " + $!
    conmsg $@
  ensure
    Curses.close_screen
  end

end

class ConsoleClient < Client
  def initialize(opts)
    super(opts)
    system('stty cbreak -echo') if !@opts.win32 && @opts.echo
  end

  def conmsg msg
    puts msg
  end

  def update(msg)
    case msg
    when Connection, :initdone
      super(msg)
    when :logged_out, :disconnected
      delete_observers
      $shutdown = true
      puts "Disconnected."
      exit
    when String
      print msg
    else
      puts "Unknown msg - #{msg.inspect}"
    end
  end

  def run
    shutdown = false
    connection = Reactor.new(@opts.port, $connopts, @opts.address)
    raise "Unable to start TeensyClient" unless connection.start(self)
    conmsg "Connected to #{@opts.address}:#{@opts.port}.  Use CTL-C to QUIT"
    until shutdown
      connection.poll(0.1)
      c = getkey
      case c
      when nil
#      when 32..127
#        message(c.chr)
      when 13
        message("\n") if @opts.win32
      when 10
        message("\n") if !@opts.win32
#      when ?D+256 # Windows F10
#        conmsg "Quitting..."
#        shutdown = true
#      when 27 # xterm F10
#        if getkey == 91 && getkey == 50 && getkey == 49 && getkey == 126
#          conmsg "Quitting..."
#          shutdown = true
#        end
      else
        message(c.chr)
#        conmsg "Unknown key hit code - #{c.inspect}"
      end
    end # until
    connection.stop
  rescue SystemExit, Interrupt
    conmsg "\nConnection closed exiting"
  rescue Exception
    conmsg "\nException caught error in client: " + $!
    conmsg $@
  ensure
    system('stty -cbreak echo') if !@opts.win32 && @opts.echo
  end

end

#
# Processes command line arguments
#
require 'optparse'
require 'ostruct'
def get_options
  # parse options
  begin
    # The myopts specified on the command line will be collected in *myopts*.
    # We set default values here.
    myopts = OpenStruct.new
    myopts.port = 4000
    myopts.address = 'localhost'
    myopts.curses = false
    myopts.echo = false
    myopts.verbose = false
    myopts.trace = false
    RUBY_PLATFORM =~ /win32/ ? myopts.win32 = true : myopts.win32 = false

    opts = OptionParser.new do |opts|
      opts.banner = BANNER
      opts.separator ""
      opts.separator "Usage: ruby #{$0} [options]"
      opts.separator ""
      opts.on("-p", "--port PORT", Integer,
        "Select the port of the mud",
        "  (defaults to 4000)") {|myopts.port|}
      opts.on("-a", "--address URL", String,
        "Select the address of the mud",
        "  (defaults to \'localhost\')") {|myopts.address|}
      opts.on("-e", "--[no-]echo", "Run in server echo mode") {|myopts.echo|}
      opts.on("-t", "--[no-]trace", "Trace execution") {|myopts.trace|}
      opts.on("-c", "--[no-]curses", "Run with curses support") {|myopts.curses|}
      opts.on("-v", "--[no-]verbose", "Run verbosely") {|myopts.verbose|}
      opts.on_tail("-h", "--help", "Show this message") do
        $stdout.puts opts.help
        exit
      end
      opts.on_tail("--version", "Show version") do
        $stdout.puts "TeensyClient #{Version}"
        exit
      end
    end

    opts.parse!(ARGV)

    return myopts
  rescue OptionParser::ParseError
    $stderr.puts "ERROR - #{$!}"
    $stderr.puts "For help..."
    $stderr.puts " ruby #{$0} --help"
    exit
  end
end


if $0 == __FILE__

  $connopts = [:client, :sockio, :zmp, :telnetfilter, :ttype, :naws, :debugfilter, :vt100]
  $opts = get_options

  if $opts.echo
    $connopts << :echo << :sga
  end

  if $opts.curses
    require 'curses'
  end

  if $opts.win32
    require 'Win32API'
    Kbhit = Win32API.new("msvcrt", "_kbhit", [], 'I')
    Getch = Win32API.new("msvcrt", "_getch", [], 'I')
    def getkey
      sleep 0.01
      return nil if Kbhit.call.zero?
      c = Getch.call
      c = Getch.call + 256 if c.zero? || c == 0xE0
      c
    end
  else
    def getkey
      select( [$stdin], nil, nil, 0.01 ) ?  c = $stdin.getc : c = nil
    end
  end

  if $opts.trace
    $tf = File.open("trace.log","w")
    set_trace_func proc { |event, file, line, id, binding, classname|
      $tf.printf "%8s %s:%-2d %10s %8s\n", event, file, line, id, classname
    }
  end

  $stdin.sync = true
  $stdout.sync = true

  if $opts.curses
    client = CursesClient.new($opts)
  else
    client = ConsoleClient.new($opts)
  end
  client.run
  $tf.close if $opts.trace
  exit

end


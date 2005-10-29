#
# file::    player.rb
# author::  Jon A. Lambert
# version:: 2.6.0
# date::    10/12/2005
#
# This source code copyright (C) 2005 by Jon A. Lambert
# All rights reserved.
#
# Released under the terms of the TeensyMUD Public License
# See LICENSE file for additional information.
#

require 'publisher'
require 'db/gameobject'

# The Player class is the mother of all players.
# Who's their daddy?
#
class Player < GameObject
  include Publisher

  # The Session object this player is connected on or nil if not connected.
  attr_accessor :session, :color

  # Create a new Player object
  # [+name+]    The displayed name of the player.
  # [+passwd+]  The player password in clear text.
  # [+session+] The session object this player is connecting on.
  # [+return+]  A handle to the new Player.
  def initialize(name,passwd,session)
    @session = session
    @passwd = encrypt(passwd)
    super(name,$engine.world.options.home)
    @powered = true

    # session related - only color settable
    @color = false
  end

  # Sends a message to the player if they are connected.
  # [+s+]      The message string
  # [+return+] Undefined.
  def sendto(s)
    publish(s+"\n") if @session
  end

  # Receives messages from a Connection being observed and handles them
  #
  # [+msg+]      The message string
  #
  # This supports the following:
  # [:logged_out] - This symbol from the server informs us that the
  #                 Connection has disconnected in an expected manner.
  # [:disconnected] - This symbol from the server informs us that the
  #                 Connection has disconnected in an unexpected manner.
  #                 There is no practical difference from :logged_out to
  #                 us.
  # [String] - A String is assumed to be input from the Session and we
  #            send it to Player#parse.
  #
  def update(msg)
    case msg
    when :logged_out
      @session = nil
      unsubscribe_all
      $engine.world.db.players_connected(@oid).each do |p|
        $engine.world.eventmgr.add_event(@oid,p.oid,:show,"#{@name} has quit.")
      end
    when :disconnected
      @session = nil
      unsubscribe_all
      $engine.world.db.players_connected(@oid).each do |p|
        $engine.world.eventmgr.add_event(@oid,p.oid,:show,"#{@name} has disconnected.")
      end
    when String
      parse(msg)
    else
      $engine.log.error "Player#update unknown message - #{msg.inspect}"
    end
  end

  # Compares the password with the players
  # [+p+] The string passed as password in clear text
  # [+return+] true if they are equal, false if not
  def check_passwd(p)
    @passwd == p.crypt(@passwd)
  end

  # Disconnects this player
  def disconnect
    publish(:logged_out)
    unsubscribe_all
    @session = nil
  end

  # All command input routed through here and parsed.
  # [+m+]      The input message to be parsed
  # [+return+] Undefined.
  def parse(m)
    # match legal command
    m=~/([A-Za-z0-9_@?"'#!\]\[]+)(.*)/
    cmd=$1
    arg=$2
    arg.strip! if arg
    if !cmd
      sendto("Huh?")
      return
    end

    # look for a command in our spanking new table
    c = $engine.world.cmds.find(cmd)

    # add any exits to our command list
    # escape certain characters in cmd
    check = cmd.gsub(/\?/,"\\?")
    check.gsub!(/\#/,"\\#")
    check.gsub!(/\[/,"\\[")
    check.gsub!(/\]/,"\\]")
    $engine.world.db.get(@location).exits.keys.grep(/^#{check}/).each do |ex|
      c << Command.new(:cmd_go,"go #{ex}",nil)
      arg = ex
    end

    # there are three possibilities here
    case c.size
    when 0   # no commands found
      sendto("Huh?")
    when 1   # command found
      self.send(c[0].cmd, arg)
    else     # ambiguous command - tell luser about them.
      ln = "Which did you mean, "
      c.each do |x|
        ln += "\'" + x.name + "\'"
        x.name == c.last.name ? ln += "?" : ln += " or "
      end
      sendto(ln)
    end
  end

  # Event handler
  # [+e+]      The event
  # [+return+] Undefined
  def ass(e)
    case e.kind
    when :describe
      msg = "[COLOR=cyan]#{@name} is here.[/COLOR]"
      $engine.world.eventmgr.add_event(@oid,e.from,:show,msg)
      fart(e)
    when :show
      sendto(e.msg)
      fart(e)
    else
      super(e)
    end
  end


private
  # Encrypts a password
  # [+passwd+] The string to be encrypted
  # [+return+] The encrypted string
  def encrypt(passwd)
    alphabet = 'abcdefghijklmnopqrstuvwxyzABCDEFGHIJKLMNOPQRSTUVWXYZ0123456789./'
    salt = "#{alphabet[rand(64)].chr}#{alphabet[rand(64)].chr}"
    passwd.crypt(salt)
  end

end


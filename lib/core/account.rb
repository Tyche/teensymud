#
# file::    account.rb
# author::  Jon A. Lambert
# version:: 2.9.0
# date::    03/15/2006
#
# This source code copyright (C) 2005, 2006 by Jon A. Lambert
# All rights reserved.
#
# Released under the terms of the TeensyMUD Public License
# See LICENSE file for additional information.
#
$:.unshift "lib" if !$:.include? "lib"

require 'utility/utility'
require 'utility/log'
require 'utility/publisher'
require 'core/root'

# The Account class handles connection login and passes them to
# character.
class Account < Root
  include Publisher
  logger 'DEBUG'
  property :color, :passwd, :characters
  attr_accessor :conn, :mode, :echo, :termsize, :terminal, :character

  # Create an Account connection.  This is a temporary object that handles
  # login for character and gets them connected.
  # [+conn+]   The session associated with this Account connection.
  # [+return+] A handle to the Account object.
  def initialize(conn)
    super("",nil)
    self.passwd = nil
    self.color = false
    self.characters = []
    @conn = conn
    @mode = :initialize
    @echo = false
    @termsize = nil
    @terminal = nil
    @checked = 3
    @account = nil
    @character = nil
  end

  # Receives messages from a Connection being observed and handles login
  # state.  On successful login the observer status will be transferred
  # to the character object.
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
  # [:initdone] - This symbol from the server indicates that the Connection
  #               is done setting up and done negotiating an initial state.
  #               It triggers us to start sending output and parsing input.
  # [:termsize] - This is sent everytime the terminal size changes (NAWS)
  # [String] - A String is assumed to be input from the Session and we
  #            parse and handle it here.
  #
  def update(msg)
    case msg
    when :logged_out, :disconnected
      @conn = nil
      unsubscribe_all
      Engine.instance.db.makeswap(id)
      if @character
        world.connected_characters.delete(@character.id)
        world.connected_characters.each do |pid|
          add_event(@character.id,pid,:show,"#{name} has #{msg.id2name}.")
        end
        Engine.instance.db.makeswap(@character.id)
        @character.account = nil
        @character = nil
      end
    when :termsize
      @termsize = @conn.query(:termsize)
      if @terminal =~ /^vt|xterm/
        publish("[home #{@termsize[1]},1][clearline][cursave]" +
          "[home 1,1][scrreset][clear][scrreg 1,#{@termsize[1]-3}][currest]")
      end
    when :initdone
      @echo = @conn.query(:echo)
      @termsize = @conn.query(:termsize)
      @terminal = @conn.query(:terminal)
      if @terminal =~ /^vt|xterm/
        publish("[home #{@termsize[1]},1][clearline][cursave]" +
          "[home 1,1][scrreset][clear][scrreg 1,#{@termsize[1]-3}][currest]")
        sendmsg(LOGO)
      end
      sendmsg(BANNER)
      sendmsg("login> ")
      @mode = :name
    when String
      case @mode
      when :initialize
        # ignore everything until negotiation done
      when :name
        publish("[clearline]") if @terminal =~ /^vt|xterm/
        @login_name = msg.proper_name
        if options['guest_accounts'] && @login_name =~ /Guest/i
          self.name = "Guest#{id}"
          @character = new_char
          Engine.instance.db.put(self)
          Engine.instance.world.all_accounts << id
          # make the account non-swappable so we dont lose connection
          Engine.instance.db.makenoswap(id)
          @conn.set(:color, color)
          welcome
          @mode = :playing
        else
          acctid = Engine.instance.world.all_accounts.find {|a|
            @login_name == Engine.instance.db.get(a).name
          }
          @account = Engine.instance.db.get(acctid)
          sendmsg("password> ")
          @conn.set(:hide, true)
          @mode = :password
        end
      when :password
        @login_passwd = msg
        @conn.set(:hide, false)
        if @account.nil?  # new account
          sendmsg("Create new user?\n'Y/y' to create, Hit enter to retry login> ")
          @mode = :newacct
        else
          if @login_passwd.is_passwd?(@account.passwd)  # good login
            # deregister all observers here and on connection
            unsubscribe_all
            @conn.unsubscribe_all
            # reregister all observers to @account
            @conn.subscribe(@account.id)
            # make the account non-swappable so we dont lose connection
            Engine.instance.db.makenoswap(@account.id)
            @conn.set(:color, @account.color)
            switch_acct(@account)
            # Check if this account already logged in
            reconnect = false
            if @account.subscriber_count > 0
              @account.unsubscribe_all
              reconnect = true
            end
            @account.subscribe(@conn)
            if options['account_system']
              sendmsg("1) Create a character\n2) Play\nQ) Quit\n> ")
              @account.mode = :menu
            else
              @character = Engine.instance.db.get(@account.characters.first)
              # make the character non-swappable so we dont lose references
              Engine.instance.db.makenoswap(@character.id)
              Engine.instance.world.connected_characters << @character.id
              @character.account = @account
              @account.character = @character
              welcome(reconnect)
              @account.mode = :playing
            end
          else  # bad login
            @checked -= 1
            sendmsg("Sorry wrong password.")
            if @checked < 1
              publish("Bye!")
              publish("[home 1,1][scrreset][clear]") if @terminal =~ /^vt|xterm/
              publish(:logged_out)
              unsubscribe_all
            else
              @mode = :name
              sendmsg("login> ")
            end
          end
        end
      when :newacct
        if msg =~ /^y/i
          self.name = @login_name
          self.passwd = @login_passwd.encrypt
          if options['account_system']
            sendmsg("1) Create a character\n2) Play\nQ) Quit\n> ")
            @mode = :menu
          else
            @character = new_char
            Engine.instance.db.put(self)
            Engine.instance.world.all_accounts << id
            # make the account non-swappable so we dont lose connection
            Engine.instance.db.makenoswap(id)
            @conn.set(:color, color)
            welcome
            @mode = :playing
          end
        else
          @mode = :name
          sendmsg("login> ")
        end
      when :menu
        case msg
        when /^1/i
        when /^2/i
        when /^Q/i
          publish("Bye!")
          publish("[home 1,1][scrreset][clear]") if @terminal =~ /^vt|xterm/
          publish(:logged_out)
          unsubscribe_all
        else
          sendmsg("1) Create a character\n2) Play\nQ) Quit\n> ")
          @mode = :menu
        end
      when :playing
        @character.parse(msg)
      else
        log.error "Account#update unknown state - #{@mode.inspect}"
      end
    else
      log.error "Account#update unknown message - #{msg.inspect}"
    end
  end

  def sendmsg(msg)
#    msg = "\n" + msg if !@echo
    publish("[cursave][home #{@termsize[1]-3},1]") if @terminal =~ /^vt|xterm/
    publish(msg)
    publish("[currest]") if @terminal =~ /^vt|xterm/
    prompt
  end

  def prompt
    if @terminal =~ /^vt|xterm/
=begin
      publish("[cursave][home #{@termsize[1]-2},1]" +
        "[color Yellow on Red]#{" "*@termsize[0]}[/color]" +
        "[home #{@termsize[1]-1},1][clearline][color Magenta](#{name})[#{@mode}][/color]" +
        "[currest][clearline]> ")
=end
      publish("[home #{@termsize[1]-2},1]" +
        "[color Yellow on Red]#{" "*@termsize[0]}[/color]" +
        "[home #{@termsize[1]-1},1][clearline][color Magenta](#{name})[#{@mode}][/color]" +
        "[home #{@termsize[1]},1][clearline]> ")
    end
  end

  def status_rept
    str = "Terminal: #{@terminal}\n"
    str << "Terminal size: #{@termsize[0]} X #{@termsize[1]}\n"
    str << "Colors toggled #{@color ? '[COLOR Magenta]ON[/COLOR]' : 'OFF' }\n"
    str << "Echo is #{@echo ? 'ON' : 'OFF' }\n"
    str << "ZMP is #{@conn.query(:zmp) ? 'ON' : 'OFF' }\n"
  end

  def toggle_color
    color ? self.color = false : self.color = true
    @conn.set(:color,color)
    "Colors toggled #{color ? '[COLOR Magenta]ON[/COLOR]' : 'OFF' }\n"
  end

private
  def new_char
    ch = Character.new(name,id)
    self.characters << ch.id
    Engine.instance.world.all_characters << ch.id
    ch.account = self
    Engine.instance.db.get(options['home'] || 1).add_contents(ch.id)
    Engine.instance.db.put(ch)
    Engine.instance.db.makenoswap(ch.id)
    Engine.instance.world.connected_characters << ch.id
    ch
  end

  def switch_acct(acct)
    acct.conn = @conn
    acct.echo = @echo
    acct.termsize = @termsize
    acct.terminal = @terminal
    acct.character = @character
  end

  def welcome(reconnect=false)
    rstr = reconnect ? 'reconnected' : 'connected'
    @character.sendto("Welcome #{@character.name}@#{@conn.query(:host)}!")
    Engine.instance.world.connected_characters.each do |pid|
      if pid != @character.id
        Engine.instance.eventmgr.add_event(@character.id,pid,:show,"#{@character.name} has #{rstr}.")
      end
    end
    @character.parse('look')
  end

end


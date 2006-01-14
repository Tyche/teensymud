#
# file::    account.rb
# author::  Jon A. Lambert
# version:: 2.6.0
# date::    10/26/2005
#
# This source code copyright (C) 2005 by Jon A. Lambert
# All rights reserved.
#
# Released under the terms of the TeensyMUD Public License
# See LICENSE file for additional information.
#

require 'publisher'

# The Account class handles connection login and passes them to
# player.
class Account
  include Publisher

  logger 'DEBUG'
  configuration

  # Create an Account connection.  This is a temporary object that handles
  # login for player and gets them connected.
  # [+conn+]   The session associated with this Account connection.
  # [+return+] A handle to the Account object.
  def initialize(conn)
    @conn = conn
    @echo = false
    @state = :name
    @checked = 3
    @player = nil
    @initdone = false # keep silent until we're done negotiating
  end

  # Receives messages from a Connection being observed and handles login
  # state.  On successful login the observer status will be transferred
  # to the player object.
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
  # [String] - A String is assumed to be input from the Session and we
  #            parse and handle it here.
  # [Array] - An Array is assumed to be the return value of a query we
  #           issued to the Connection.  Currently no queries or set
  #           requests are made from Account (see Player).
  #
  #         <pre>
  #         us     -> Connection
  #             query :color
  #         Connection -> us
  #             [:color, true]
  #         </pre>
  #
  def update(msg)
    case msg
    when :logged_out, :disconnected
      unsubscribe_all
    when :initdone
      @echo = @conn.query(:echo)
      @initdone = true
      publish(BANNER)
      ts = @conn.query(:termsize)
 # ansi test COMMENTED OUT as this screws up some clients
#      publish("[cursave]")
#      15.times do
#        publish("[home #{rand(ts[1])+1},#{rand(ts[0])+1}]*")
#      end
#      publish("[currest]")
      prompt("login> ")
    when String
      if @initdone
        case @state
        when :name
          @login_name = msg
          @player = $engine.world.find_player_by_name(@login_name)
          prompt("password> ")
          @conn.set(:hide, true)
          @state = :password
        when :password
          @login_passwd = msg
          @conn.set(:hide, false)
          if @player
            if @player.check_passwd(@login_passwd)  # good login
              @player.session = @conn
              login
            else  # bad login
              @checked -= 1
              prompt("Sorry wrong password.\n")
              if @checked < 1
                publish("Bye!\n")
                publish(:logged_out)
                unsubscribe_all
              else
                @state = :name
                publish("login> ")
              end
            end
          else  # new player
            prompt("Create new user?\n'Y'|'y' to create, Enter to retry login> ")
            @state = :new
          end
        when :new
          if msg =~ /^[Yy]/
            @player = Player.new(@login_name,@login_passwd,@conn)
            if @player.nil?
              log.error "Unable to create player"
              prompt "System error: unable to create player."
              @state = :name
              prompt("login> ")
            else
              $engine.world.db.put(@player)
              $engine.world.db.get(options['home'] || 1).add_contents(@player.id)
              login
            end
          else
            @state = :name
            prompt("login> ")
          end
        end
      end
    else
      log.error "Account#update unknown message - #{msg.inspect}"
    end
  end

private
  def prompt(msg)
    msg = "\n" + msg if !@echo
    publish(msg)
  end

  # Called on successful login
  def login
    @conn.set(:color, @player.color)

    # Check if this player already logged in
    if @player.subscriber_count > 0
      @player.publish(:reconnecting)
      @player.unsubscribe_all
      @player.sendto("\nWelcome reconnecting #{@login_name}@#{@conn.query(:host)}!")
    end

    # deregister all observers here and on connection
    unsubscribe_all
    @conn.unsubscribe_all

    # reregister all observers to @player
    @conn.subscribe(@player)
    @player.subscribe(@conn)

    @player.sendto("\nWelcome #{@login_name}@#{@conn.query(:host)}!")
    $engine.world.players_connected(@player.id).each {|p|
      $engine.world.eventmgr.add_event(@player.id,p.id,:show,"#{@player.name} has connected.")
    }


    @player.parse('look')
  end

end


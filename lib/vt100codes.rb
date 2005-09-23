#
# file::    vt100codes.rb
# author::  Jon A. Lambert
# version:: 2.5.4
# date::    09/21/2005
#
# This source code copyright (C) 2005 by Jon A. Lambert
# All rights reserved.
#
# Released under the terms of the TeensyMUD Public License
# See LICENSE file for additional information.
#

# This module contains the contants used for Telnet
module VT100Codes

  CSI =  "\e["     # Control sequence
  SS3 =  "\eO"     #
  IND =  "\eD"     #

  # Final bytes
  SGR =  "m"       # Graphic rendering

  DVC =  "\e[c"    # Requests Device code - response is \e[<code>0c
  DVST = "\e[5n"   # Request device status - response is \e[0n (OK) or \e[3n (Failure)
  QCP = "\e[6n"    # Query cursor position - response is \e[<row>;<col>R

  RD  = "\ec"      # Reset all terminal settings to default.
  ELW = "\e[7h"     # Enable line wrap
  DLW = "\e[7l"     # Disable line wrap

  HOME = "H"       # Home \e[H or \e[<row>;<col>H
  HOMEF = "f"       # Home \e[H or \e[<row>;<col>H
  UP   = "A"       # Up \e[A or \e[<count>A
  DOWN = "B"       # Up \e[B or \e[<count>B
  RIGHT = "C"      # Up \e[C or \e[<count>C
  LEFT  = "D"      # Up \e[D or \e[<count>D
  SCURS = "\e[s"   # save cursor position
  RCURS = "\e[u"   # restore cursor position
  SCURA = "\e7"    # save cursor pos and attributes
  RCURA = "\e7"    # restore cursor pos and attributes

  SDF = "\e("      # Set default font
  SAF = "\e)"      # Set alternate font

  SS  = "r"     # Enable scrolling entire display \e[r or just a region \e[<srow>;<erow>r
  SD  = "\eD"   # Scroll down
  SU  = "\eU"   # Scroll up

  ST  = "\eH"   # Sets tab at cur pos
  CT  = "\e[g"   # Clears tab at cur pos
  CTA = "\e[3g"  # Clears all tabs


  EEOL = "\e[K"  # Erase to end of line
  ESOL = "\e[1K" # Erase to start of line
  ERL  = "\e[2K" # Erase entire line
  ED   = "\e[J"  # Erase cur line down
  EU   = "\e[1J" # Erase cur line up
  ES   = "\e[2J" # Erase screen and goes to home


  BSPC = "\177"
  W_BSPC = "\010"
  INS= "\e[2~"
  DEL= "\e[3~"
  W_DEL = "\177"

  X_HOMEKEY = "\e[7~"
  X_ENDKEY = "\e[8~"
  V_HOMEKEY = "\e[1~"
  V_ENDKEY = "\e[4~"
  PAGEUP = "\e[5~"
  PAGEDOWN = "\e[6~"

  W_F1 = "\eOP"
  W_F2 = "\eOQ"
  W_F3 = "\eOR"
  W_F4 = "\eOS"

  F1 = "\e[11~"
  F2 = "\e[12~"
  F3 = "\e[13~"
  F4 = "\e[14~"
  F5 = "\e[15~"
  F6 = "\e[17~"
  F7 = "\e[18~"
  F8 = "\e[19~"
  F9 = "\e[20~"
  F10= "\e[21~"

  SF1 = "\e[23~"
  SF2 = "\e[24~"
  SF3 = "\e[25~"
  SF4 = "\e[26~"
  SF5 = "\e[28~"
  SF6 = "\e[29~"
  SF7 = "\e[31~"
  SF8 = "\e[32~"
  SF9 = "\e[33~"
  SF10= "\e[34~"

end
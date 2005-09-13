#
# file::    command.rb
# author::  Jon A. Lambert
# version:: 2.2.0
# date::    08/29/2005
#
# This source code copyright (C) 2005 by Jon A. Lambert
# All rights reserved.
#
# Released under the terms of the TeensyMUD Public License
# See LICENSE file for additional information.
#

if $0 == __FILE__
  Dir.chdir("..")
  $:.unshift "lib"
end

require 'yaml'
require 'ternarytrie'


# The Command class encapsulates a TeensyMud command
class Command
  attr_reader :cmd, :name, :help

  # Create a command
  def initialize(cmd, name, help)
    @cmd,@name,@help=cmd,name,help
  end

  # load builds a command lookup trie from the commands listed in a yaml
  # config file and in the and then defines/redefines them on the Player
  # class.
  # [+return+] A trie of commands (see TernaryTrie class)
  def self.load(fname,forclass,mname)
    cmds = YAML::load_file("cmd/" + fname)
    cmdtable = TernaryTrie.new
    cmds.each do |c|
      Kernel::load("cmd/" + c.cmd.to_s + ".rb")
      cmdtable.insert(c.name, c)
    end
    forclass.send(:include,const_get(mname))
    cmdtable
  rescue Exception
    puts $!
    puts $@
  end

end


if $0 == __FILE__
  require 'pp'
  class Player
  end

  cmdtable = Command.load
  puts "--dump---------------------------"
  pp cmdtable.to_hash.values
  puts "--pp cmdtable--------------------"
  pp cmdtable
  puts "--execute commands---------------"
  p = Player.new
  c = cmdtable.find_exact("help")
  p.send(c.cmd)
  c = cmdtable.find_exact("look")
  p.send(c.cmd)
  c = cmdtable.find("l")
  p.send(c[0].cmd)

end


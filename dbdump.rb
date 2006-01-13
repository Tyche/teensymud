#!/usr/bin/env ruby
#
# file::    dbdump.rb
# author::  Jon A. Lambert
# version:: 2.7.0
# date::    1/12/2006
#
# This source code copyright (C) 2005 by Jon A. Lambert
# All rights reserved.
#
# Released under the terms of the TeensyMUD Public License
# See LICENSE file for additional information.
#

# This utility program dumps a database to yaml
#

$:.unshift "lib"
require 'yaml'
require 'pp'
require 'db/properties'
require 'db/player'
require 'db/room'
require 'farts/farts_parser'

$dbtop = 0
$db = {}
$count = 0

case ARGV[1]
when 'sdbm'
  require 'sdbm'
  SDBM.open(ARGV[0], 0666) do |db|
    db.each_value do |v|
      o = YAML::load(v)
      $dbtop = o.id if o.id > $dbtop
      $db[o.id]=o
      $count += 1
    end
  end
when 'gdbm'
  require 'gdbm'
  GDBM.open("#{ARGV[0]}.gdbm", 0666) do |db|
    db.each_value do |v|
      o = YAML::load(v)
      $dbtop = o.id if o.id > $dbtop
      $db[o.id]=o
      $count += 1
    end
  end
when 'dbm'
  require 'dbm'
  DBM.open(ARGV[0], 0666) do |db|
    db.each_value do |v|
      o = YAML::load(v)
      $dbtop = o.id if o.id > $dbtop
      $db[o.id]=o
      $count += 1
    end
  end
end

File.open("#{ARGV[0]}.yaml",'w') do |f|
  YAML::dump($db.values,f)
end

puts "Highest object in use: #{$dbtop}"
puts "Count of objects dumped: #{$count}"
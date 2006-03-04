#!/usr/bin/env ruby
#
# file::    dbdump.rb
# author::  Jon A. Lambert
# version:: 2.8.0
# date::    01/19/2006
#
# This source code copyright (C) 2005, 2006 by Jon A. Lambert
# All rights reserved.
#
# Released under the terms of the TeensyMUD Public License
# See LICENSE file for additional information.
#
$:.unshift "lib" if !$:.include? "lib"
$:.unshift "vendor" if !$:.include? "vendor"

require 'yaml'
require 'optparse'
require 'ostruct'
require 'pp'
require 'storage/properties'
require 'core/player'
require 'core/room'
require 'core/world'
require 'core/script'

# This utility program dumps a database to yaml
#
class Dumper
  VERSION = "0.1.0"

  attr_accessor :opts
  DATABASES = [:dbm, :gdbm, :sdbm]

  def initialize
    @opts = get_options
    case @opts.dbtype
    when :dbm
      require 'dbm'
    when :gdbm
      require 'gdbm'
    when :sdbm
      require 'sdbm'
    end
    @dbtop = 0
    @db = {}
    @count = 0
  end

  #
  # Processes command line arguments
  #
  def get_options

    # The myopts specified on the command line will be collected in *myopts*.
    # We set default values here.
    myopts = OpenStruct.new
    myopts.ifile = nil
    myopts.ofile = nil
    myopts.dbtype = nil

    opts = OptionParser.new do |opts|
      opts.banner = "Database Dumper #{VERSION}"
      opts.separator ""
      opts.separator "Usage: ruby #{$0} [options]"
      opts.separator ""
      opts.separator "Options:"
      opts.on("-i", "--ifile FILE", String,
              "Select the database file to read",
              "  extension determined automatically") {|myopts.ifile|}
      opts.on("-o", "--ofile FILE", String,
              "Select the yaml file to write",
              "  defaults to same as database") {|myopts.ofile|}
      opts.on("-t", "--type DBTYPE", DATABASES,
              "Select the database type - required (no default)",
              "  One of: #{DATABASES.join(", ")}",
              "    Example: -t gdbm") {|myopts.dbtype|}
      opts.on_tail("-h", "--help", "Show this message") do
        puts opts.help
        exit
      end
      opts.on_tail("-v", "--version", "Show version") do
        puts "Database Dumper #{VERSION}"
        exit
      end
    end

    opts.parse!(ARGV)
    raise(OptionParser::MissingArgument.new("-t")) if myopts.dbtype == nil
    raise(OptionParser::ParseError, "Must specify input file!") if myopts.ifile.nil?
    myopts.ofile = myopts.ifile.dup if myopts.ofile.nil?
    myopts.ifile << ".gdbm" if myopts.dbtype == :gdbm
    myopts.ofile << ".yaml"

    return myopts
  rescue OptionParser::ParseError
    puts "ERROR - #{$!}"
    puts "For help..."
    puts " ruby #{$0} --help"
    exit
  end

  def store(v)
    o = Marshal.load(v)
    @dbtop = o.id if o.id > @dbtop
    @db[o.id]=o
    @count += 1
  end

  #
  # Launches the dumper
  #
  def run
    case @opts.dbtype
    when :sdbm
      SDBM.open(@opts.ifile, 0666) do |db|
        db.each_value {|v| store v}
      end
    when :gdbm
      GDBM.open(@opts.ifile, 0666) do |db|
        db.each_value {|v| store v}
      end
    when :dbm
      DBM.open(@opts.ifile, 0666) do |db|
        db.each_value {|v| store v}
      end
    end

    File.open(@opts.ofile,'wb') do |f|
      YAML::dump(@db.values,f)
    end

    puts "Highest object in use   : #{@dbtop}"
    puts "Count of objects dumped : #{@count}"
  end

end

app = Dumper.new.run


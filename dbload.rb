#!/usr/bin/env ruby
#
# file::    dbload.rb
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

# This utility program loads a yaml file to a database
#

$:.unshift "lib"
require 'yaml'
require 'optparse'
require 'ostruct'
require 'pp'
require 'db/properties'
require 'db/player'
require 'db/room'
require 'farts/farts_parser'

#
# TODO: Add Description Here
#
class Loader
  VERSION = "0.1.0"

  attr_accessor :opts
  DATABASES = [:dbm, :gdbm, :sdbm]

  #
  # TODO: Add description here
  #
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
      opts.banner = "Database Loader #{VERSION}"
      opts.separator ""
      opts.separator "Usage: ruby #{$0} [options]"
      opts.separator ""
      opts.separator "Options:"
      opts.on("-i", "--ifile FILE", String,
              "Select the yaml file to read",
              "  defaults to same as database") {|myopts.ifile|}
      opts.on("-o", "--ofile FILE", String,
              "Select the database file to write",
              "  extension determined automatically") {|myopts.ofile|}
      opts.on("-t", "--type DBTYPE", DATABASES,
              "Select the database type - required (no default)",
              "  One of: #{DATABASES.join(", ")}",
              "    Example: -t gdbm") {|myopts.dbtype|}
      opts.on_tail("-h", "--help", "Show this message") do
        puts opts.help
        exit
      end
      opts.on_tail("-v", "--version", "Show version") do
        puts "Database Loader #{VERSION}"
        exit
      end
    end

    opts.parse!(ARGV)
    raise(OptionParser::MissingArgument.new("-t")) if myopts.dbtype == nil
    raise(OptionParser::ParseError, "Must specify input file!") if myopts.ifile.nil?
    myopts.ofile = myopts.ifile.dup if myopts.ofile.nil?
    myopts.ofile << ".gdbm" if myopts.dbtype == :gdbm
    myopts.ifile << ".yaml"

    return myopts
  rescue OptionParser::ParseError
    puts "ERROR - #{$!}"
    puts "For help..."
    puts " ruby #{$0} --help"
    exit
  end

  #
  # Launches the loader
  #
  def run

    YAML::load_file(@opts.ifile).each do |o|
      @dbtop = o.id if o.id > @dbtop
      @db[o.id]=o
      @count += 1
    end

    case @opts.dbtype
    when :sdbm
      SDBM.open(@opts.ofile, 0666) do |db|
        @db.each {|k,v| db[k.to_s] = YAML::dump(v)}
      end
    when :gdbm
      GDBM.open(@opts.ofile, 0666) do |db|
        @db.each {|k,v| db[k.to_s] = YAML::dump(v)}
      end
    when :dbm
      DBM.open(@opts.ofile, 0666) do |db|
        @db.each {|k,v| db[k.to_s] = YAML::dump(v)}
      end
    end

    puts "Highest object in use   : #{@dbtop}"
    puts "Count of objects dumped : #{@count}"
  end

end

app = Loader.new.run


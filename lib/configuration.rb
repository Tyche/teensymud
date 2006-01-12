#
# file::    config.rb
# author::  Jon A. Lambert
# version:: 2.7.0
# date::    01/08/2006
#
# This source code copyright (C) 2005 by Jon A. Lambert
# All rights reserved.
#
# Released under the terms of the TeensyMUD Public License
# See LICENSE file for additional information.
#

require 'singleton'
require 'yaml'
require 'optparse'
require 'version'

# The Config class is a singleton that allows class level configuration
#
class Configuration
  include Singleton
  attr_reader :options

  # Load logger configuration
  def initialize
    cmdopts = get_options
  begin
    @options = YAML::load_file(cmdopts['configfile'] || 'config.yaml')
  rescue
    $stderr.puts "WARNING - configuration file not found"
    @options = {}
  end
    cmdopts.each do |key,val|
      @options[key] = val
    end
  end

private
  #
  # Processes command line arguments
  #
  def get_options
    # parse options
    begin
      # The myopts specified on the command line will be collected in *myopts*.
      # We set default values here.
      myopts = {}

      opts = OptionParser.new do |opts|
        opts.banner = BANNER
        opts.separator ""
        opts.separator "Usage: ruby #{$0} [options]"
        opts.separator ""
        opts.on("-p", "--port PORT", Integer,
          "Select the port the mud will run on") {|myopts['port']|}
        opts.on("-d", "--dbfile DBFILE", String,
          "Select the name of the database file",
          "  (default is 'db/world.yaml')") {|myopts['dbfile']|}
        opts.on("-c", "--config CONFIGFILE", String,
          "Select the name of the configuration file",
          "  (default is 'config.yaml')") {|myopts['configfile']|}
        opts.on("-l", "--logfile LOGFILE", String,
          "Select the name of the log file",
          "  (default is 'logs/server.log')") {|myopts['logfile']|}
        opts.on("-h", "--home LOCATIONID", Integer,
          "Select the object id where new players will start") {|myopts['home']|}
        opts.on("-t", "--[no-]trace", "Trace execution") {|myopts['trace']|}
        opts.on("-v", "--[no-]verbose", "Run verbosely") {|myopts['verbose']|}
        opts.on_tail("-h", "--help", "Show this message") do
          $stdout.puts opts.help
          exit
        end
        opts.on_tail("--version", "Show version") do
          $stdout.puts "TeensyMud #{Version}"
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


end

class Module

# configure adds the options method to a class which allows it to access
# the global configuration hash.
#
# [+name+] an arrays of symbols representing the attributes on the object.
  def configuration()
    class_eval <<-EOD
      def options
        Configuration.instance.options
      end
    EOD
  end
end


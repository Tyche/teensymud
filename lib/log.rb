#
# file::    log.rb
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
require 'log4r'

# The Log class is a singleton that handles logging at the class level
#
class Log
  include Singleton
  include Log4r

  # Load logger configuration
  def initialize
    Logger['global'].level = DEBUG
    fmt = PatternFormatter.new(:pattern => "%d [%5l] (%c) %M",
                               :date_pattern => "%y-%m-%d %H:%M:%S")
    @stderr = StderrOutputter.new('stderr', :level => DEBUG, :formatter => fmt)
    @server = FileOutputter.new('server', :level => DEBUG, :formatter => fmt,
                       :filename => 'logs/server.log' , :trunc => 'false')
  end

  # Access a logger class
  # [+logname+]  The name of the logger
  # [+loglevel+] the level of logging to do
  def loginit(logname, loglevel='DEBUG')
    Logger.new(logname, Log4r.const_get(loglevel)).outputters = @stderr, @server
    Logger[logname]
  end

end

class Module

# logger defines a named log and log method for the class
#
# [+loglevel+] the level of logging to do
  def logger(loglevel='DEBUG')
    class_eval <<-EOD
      @log = Log.instance.loginit(self.name, "#{loglevel}")
      def log
        self.class.instance_variable_get :@log
      end
    EOD
  end
end


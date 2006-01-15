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

  def initialize
    if $cmdopts && $cmdopts['configfile']
      @options = YAML::load_file($cmdopts['configfile'])
    else
      @options = YAML::load_file('config.yaml')
    end
  rescue
    $stderr.puts "WARNING - configuration file not found"
    @options = {}
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


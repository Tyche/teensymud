#
# file::    properties.rb
# author::  Jon A. Lambert
# version:: 2.6.0
# date::    10/12/2005
#
# This source code copyright (C) 2005 by Jon A. Lambert
# All rights reserved.
#
# Released under the terms of the TeensyMUD Public License
# See LICENSE file for additional information.
#

class Module

# Properties modifies class Module by adding the property method which:
# 1. creates read/write accessors for each symbol.
# 2. defines the to_yaml_properties for use by the database for all symbols.
# 3. defines the :id attribute
#
# [+sym+] an arrays of symbols representing the attributes on the object.
  def property(*sym)
    sym.each do |s|
      class_eval <<-EOD
        def #{s}
          @props ||= {}
          @props[:#{s}]
        end
        def #{s}=(val)
          @props ||= {}
          @props[:#{s}] = val
          $engine.world.db.put(self) if $engine.world.db.check(id)
          @props[:#{s}]
        end
      EOD
    end
    class_eval <<-EOD
      def to_yaml_properties
        ['@props']
      end
      def id
        @props ||= {}
        @props[:id] ||= $engine.world.db.getid
      end
    EOD
  end

end

if $0 == __FILE__
  require 'pp'
  require 'yaml'

  class A
   property :a, :b
   property :p, :q, :r

   def initialize
     @x = "string"
   end
  end

  a = A.new
  pp a
  a.a = 1
  pp a
  y a
  a.id
  pp a
  y a

  pp a.to_yaml

  p a.to_yaml_properties.inspect

  puts "================="
  class B < A
   property :a, :y, :z
   def initialize
     super
   end
   def stuff
     puts @q.inspect
   end
  end

  b = B.new
  b.q ="heya"
  b.id
  b.y = {1=>"one", 2=>"two"}
  pp b


  y b
  p b.to_yaml_properties.inspect

  b.stuff

  $db = []
  $db << a
  $db << b

  File.open("proptest.yaml",'w'){|f|YAML::dump($db,f)}

end

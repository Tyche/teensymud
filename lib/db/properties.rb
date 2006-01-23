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
    if Configuration.instance.options['props_are_accessors_only']
      attr_accessor(*sym)
=begin
      class_eval <<-EOD
        def id
          @id ||= Engine.instance.db.getid
        end
      EOD
=end
      return
    end
    sym.each do |s|
      class_eval <<-EOD
        def #{s}
          @props ||= {}
          if options['safe_read'] && !@props[:#{s}].kind_of?(Numeric)
            Engine.instance.db.mark(self.id)
          end
          @props[:#{s}]
        end
        def #{s}=(val)
          @props ||= {}
          Engine.instance.db.mark(self.id)
          @props[:#{s}] = val
        end
      EOD
    end
    class_eval <<-EOD
      def to_yaml_properties
        ['@props']
      end
      def id
        @props ||= {}
        @props[:id] ||= Engine.instance.db.getid
      end
    EOD
  end

end


#
# file::    utility.rb
# author::  Jon A. Lambert
# version:: 2.9.0
# date::    03/12/2006
#
# This source code copyright (C) 2005, 2006 by Jon A. Lambert
# All rights reserved.
#
# Released under the terms of the TeensyMUD Public License
# See LICENSE file for additional information.
#

class String

  # Checks if 'str' is a prefix of this string
  def is_prefix? str
    return false if self.empty? || str.nil? || str.empty?
    self.downcase == str.slice(0...self.size).downcase
  end

  # Takes a string containing a list of keywords, like 'hello world',
  # and checks if 'str' is a prefix of any of those words?
  # "hell" would be true
  def is_match? str
    return false if self.empty? || str.nil? || str.empty?
    lst = self.split(' ')
    lst.each do |s|
      return true if str.downcase == s.slice(0...str.size).downcase
    end
    false
  end
end

module Utility


end


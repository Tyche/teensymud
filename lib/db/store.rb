#
# file::    store.rb
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

# The minimal database will be used in the absence of detecting one.
MINIMAL_DB=<<EOH
---
- !ruby/object:Room
  props:
    :location:
    :powered: false
    :id: 1
    :desc: "This is home."
    :contents: []
    :exits: {}
    :farts: {}
    :name: Home
EOH


# The Store class is an abstract class defining the methods
# needed to access a data store
#
class Store

  # Construct store
  #
  # [+return+] Handle to the store
  def initialize
    @dbtop = 0
  end

  # Close the store
  # [+return+] Undefined.
  def close
  end

  # Reset the store
  # [+return+] Undefined.
  def reset
  end

  # Save or flush the store to disk
  # [+return+] Undefined.
  def save
  end

  # Fetch the next available id.
  # [+return+] An id.
  def getid
    @dbtop+=1
  end

  # Finds an object in the database by its id.
  # [+oid+] is the id to use in the search.
  # [+return+] Handle to the object or nil.
  def get(oid)
    nil
  end

  # Check if an object is in the database by its id.
  # [+oid+] is the id to use in the search.
  # [+return+] true or false
  def check(oid)
    false
  end

  # Adds a new object to the database.
  # [+obj+] is a reference to object to be added
  # [+return+] Undefined.
  def put(obj)
  end

  # Deletes an object from the database.
  # [+oid+] is the id to to be deleted.
  # [+return+] Undefined.
  def delete(oid)
  end

  # Iterate through all objects
  # [+yield+] Each object in database to block of caller.
  def each
  end

  # produces a statistical report of the database
  # [+return+] a string containing the report
  def stats
    rooms = objs = players = 0
    self.each do |val|
      case val
      when Room
        rooms += 1
      when Player
        players += 1
      when GameObject
        objs += 1
      end
    end
    stats=<<EOD
[COLOR=cyan]
---* Database Statistics *---
  Rooms   - #{rooms}
  Players - #{players}
  Objects - #{objs}
  Total Objects - #{rooms+objs+players}
  Highest OID in use - #{@dbtop}
---*                     *---
[/COLOR]
EOD
  end

end

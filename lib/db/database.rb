#
# file::    database.rb
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


# The Database class manages all object storage.
#
# [+db+] is a handle to the database implementation (in this iteration a hash).
# [+dbtop+] stores the highest oid used in the database.
# [+dbname+] stores the file name of the database.
class Database

# The minimal database will be used in the absence of detecting one.
MINIMAL_DB=<<EOH
---
- !ruby/object:Room
  exits: {}
  farts: {}
  contents: []
  location:
  desc: "This is home."
  name: Home
  oid: 1
EOH

  def initialize(log, opts)
    @log, @dbname = log, opts.dbname
    if !test(?e,@dbname)
      @log.info "Building minimal world database..."
      File.open(@dbname,'w') do |f|
        f.write(MINIMAL_DB)
      end
      @log.info "Done."
    end
    @log.info "Loading world..."
    @dbtop = 0
    @db = {}
    tmp = YAML::load_file(@dbname)
    # calculate the dbtop
    tmp.each do |o|
      @dbtop = o.oid if o.oid > @dbtop
      @db[o.oid]=o
    end
    @log.info "Done database loaded...top oid=#{@dbtop}."
  end

  # Fetch the next available oid.
  # [+return+] An oid.
  def getid
    @dbtop+=1
  end

  # Save the world
  # [+return+] Undefined.
  def save
    File.open(@dbname,'w'){|f|YAML::dump(@db.values,f)}
  end

  # Adds a new object to the database.
  # [+obj+] is a reference to object to be added
  # [+return+] Undefined.
  def put(obj)
    @db[obj.oid] = obj
  end

  # Deletes an object from the database.
  # [+oid+] is the oid to to be deleted.
  # [+return+] Undefined.
  def delete(oid)
    @db.delete(oid)
  end

  # Finds an object in the database by its oid.
  # [+oid+] is the oid to use in the search.
  # [+return+] Handle to the object or nil.
  def get(oid)
    @db[oid]
  end

  # Finds a Player object in the database by name.
  # [+nm+] is the string to use in the search.
  # [+return+] Handle to the Player object or nil.
  def find_player_by_name(nm)
    @db.values.find{|o| Player == o.class && nm == o.name}
  end

  # Finds all connected players
  # [+exempt+] The oid of a player to be exempt from the returned array.
  # [+return+] An array of  connected players
  def players_connected(exempt=nil)
    @db.values.find_all{|o| o.class == Player && o.oid != exempt && o.session}
  end

  # Iterate through all objects
  # [+yield+] Each object in database to block of caller.
  def objects
    @db.values.each{|obj| yield(obj)}
  end

  # produces a statistical report of the database
  # [+return+] a string containing the report
  def stats
    rooms = objs = players = 0
    @db.values.each do |val|
      case val
      when Room
        rooms += 1
      when Player
        players += 1
      when GameObject
        objs += 1
      end
    end
    stats=<<EOH
[COLOR=cyan]
---* Database Statistics *---
  Rooms   - #{rooms}
  Players - #{players}
  Objects - #{objs}
  Total Objects - #{rooms+objs+players}
  Highest OID in use - #{@dbtop}
---*                     *---
[/COLOR]
EOH
    return stats
  end

end

#
# file::    database.rb
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


# The Database class manages all object storage.
#
# [+db+] is a handle to the database implementation (in this iteration a hash).
# [+dbtop+] stores the highest id used in the database.
class Database
  configuration
  logger 'DEBUG'

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


  def initialize
    require 'yaml'
    case options['dbtype']
    when :yaml
      if !test(?e, "#{options['dbfile']}.yaml")
        log.info "Building minimal world database..."
        File.open("#{options['dbfile']}.yaml",'w') do |f|
          f.write(MINIMAL_DB)
        end
      end
    when :gdbm
      require 'gdbm'
      if !test(?e, "#{options['dbfile']}.gdbm")
        log.info "Building minimal world database..."
        tmp = YAML::load(MINIMAL_DB)
        GDBM.open("#{options['dbfile']}.gdbm", 0666) do |db|
          tmp.each do |o|
            db[o.id.to_s] = YAML::dump(o)
          end
        end
      end
    when :sdbm
      require 'sdbm'
      if !test(?e, "#{options['dbfile']}.pag")
        log.info "Building minimal world database..."
        tmp = YAML::load(MINIMAL_DB)
        SDBM.open(options['dbfile'], 0666) do |db|
          tmp.each do |o|
            db[o.id.to_s] = YAML::dump(o)
          end
        end
      end
    when :dbm
      require 'dbm'
      if !test(?e, "#{options['dbfile']}.db")
        log.info "Building minimal world database..."
        tmp = YAML::load(MINIMAL_DB)
        DBM.open(options['dbfile'], 0666) do |db|
          tmp.each do |o|
            db[o.id.to_s] = YAML::dump(o)
          end
        end
      end
    else
      raise "Unable to load database module for #{options['dbtype']}"
    end

    log.info "Loading world..."
    @dbtop = 0
    @db = {}

    case options['dbtype']
    when :yaml
      YAML::load_file("#{options['dbfile']}.yaml").each do |o|
        @dbtop = o.id if o.id > @dbtop
        @db[o.id]=o
      end
    when :gdbm
      GDBM.open("#{options['dbfile']}.gdbm", 0666) do |db|
        db.each_value do |v|
          o = YAML::load(v)
          @dbtop = o.id if o.id > @dbtop
          @db[o.id]=o
        end
      end
    when :sdbm
      SDBM.open(options['dbfile'], 0666) do |db|
        db.each_value do |v|
          o = YAML::load(v)
          @dbtop = o.id if o.id > @dbtop
          @db[o.id]=o
        end
      end
    when :dbm
      DBM.open(options['dbfile'], 0666) do |db|
        db.each_value do |v|
          o = YAML::load(v)
          @dbtop = o.id if o.id > @dbtop
          @db[o.id]=o
        end
      end
    end

    # calculate the dbtop
    log.info "Done database loaded...top id=#{@dbtop}."
#    log.debug @db.inspect
  rescue
    log.fatal $!
    raise
  end

  # Fetch the next available id.
  # [+return+] An id.
  def getid
    @dbtop+=1
  end

  # Save the world
  # [+return+] Undefined.
  def save
    case options['dbtype']
    when :yaml
      File.open("#{options['dbfile']}.yaml",'w') do |f|
        YAML::dump(@db.values,f)
      end
    when :gdbm
      GDBM.open("#{options['dbfile']}.gdbm", 0666) do |db|
        @db.each do |k,v|
          db[k.to_s] = YAML::dump(v)
        end
      end
    when :sdbm
      SDBM.open(options['dbfile'], 0666) do |db|
        @db.each do |k,v|
          db[k.to_s] = YAML::dump(v)
        end
      end
    when :dbm
      DBM.open(options['dbfile'], 0666) do |db|
        @db.each do |k,v|
          db[k.to_s] = YAML::dump(v)
        end
      end
    end
  end

  # Adds a new object to the database.
  # [+obj+] is a reference to object to be added
  # [+return+] Undefined.
  def put(obj)
    @db[obj.id] = obj
  end

  # Deletes an object from the database.
  # [+oid+] is the id to to be deleted.
  # [+return+] Undefined.
  def delete(oid)
    @db.delete(oid)
  end

  # Finds an object in the database by its id.
  # [+oid+] is the id to use in the search.
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
  # [+exempt+] The id of a player to be exempt from the returned array.
  # [+return+] An array of  connected players
  def players_connected(exempt=nil)
    @db.values.find_all{|o| o.class == Player && o.id != exempt && o.session}
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

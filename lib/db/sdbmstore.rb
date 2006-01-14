#
# file::    sdbmstore.rb
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

require 'sdbm'
require 'log'
require 'db/store'
require 'db/cache'

# The SdbmStore class manages access to all object storage.
#
# [+db+] is a handle to the database.
# [+dbtop+] stores the highest id used in the database.
# [+cache+] is a handle to the cache
class SdbmStore < Store
  logger 'DEBUG'

  def initialize(dbfile)
    super()
    @dbfile = "#{dbfile}"

    # check if database exists and build it if not
    build_database
    log.info "Loading world..."

    # open database and sets @dbtop to highest object id
    @db = SDBM.open(@dbfile, 0666)
    @db.each_key do |o|
      @dbtop = o.to_i if o.to_i > @dbtop
    end

    @cache = CacheManager.new(@db)
    log.info "Database '#{@dbfile}' loaded...highest id = #{@dbtop}."
#    log.debug @db.inspect
  rescue
    log.fatal $!
    raise
  end

  # Save the world
  # [+return+] Undefined.
  def save
    @cache.sync
  end

  # Close the database
  # [+return+] Undefined.
  def close
    @db.close
  end

  # Adds a new object to the database.
  # [+obj+] is a reference to object to be added
  # [+return+] Undefined.
  def put(obj)
    @cache.put(obj)
    obj # return really should not be checked
  end

  # Deletes an object from the database.
  # [+oid+] is the id to to be deleted.
  # [+return+] Undefined.
  def delete(oid)
    @cache.delete(oid)
  end

  # Finds an object in the database by its id.
  # [+oid+] is the id to use in the search.
  # [+return+] Handle to the object or nil.
  def get(oid)
    @cache.get(oid)
  end

  # Iterate through all objects this needs to go directly to database
  # so we must sync the cache first.  Then we reset the cache.
  # [+yield+] Each object in database to block of caller.
  def each
    @cache.sync
    @db.each_value{|obj| yield(YAML::load(obj))}
    @cache.reset
  end

  # produces a statistical report of the database
  # [+return+] a string containing the report
  def stats
    stats = super
    stats << @cache.stats
  end

private

  # Checks that the database exists and builds one if not
  # Will raise an exception if something goes wrong.
  def build_database
    if !test(?e, @dbfile)
      log.info "Building minimal world database..."
      SDBM.open(@dbfile, 0666) do |db|
        YAML::load(MINIMAL_DB).each do |o|
          db[o.id.to_s] = YAML::dump(o)
        end
      end
    end
  rescue
    log.fatal "Unable to find or build database - '#{options['dbfile']}'[#{options['dbtype']}]"
    log.fatal $!
    raise
  end

end

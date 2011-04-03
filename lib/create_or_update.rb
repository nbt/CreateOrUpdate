module CreateOrUpdate

  def self.included(base)
    base.extend(ClassMethods)
    base.send(:include, InstanceMethods)
  end

  # ================================================================
  module ClassMethods

    DEFAULT_OPTIONS = {
      :if_exists => :ignore,
      :db_adaptor => ActiveRecord::Base.connection.adapter_name
     }

    RECOGNIZED_DB_ADAPTORS = %w(ActiveRecord MySQL PostgreSQL SQLite)

    # Insert new records into or update incumbent records in a table.
    # Records is an array of active records, keys defines which columns
    # are considered in determining if a record is unique.  
    #
    # As a special case, a blank value for keys implies "no records
    # match" (as opposed to "all records match"), with the result that
    # all candidate records WILL be inserted, no existing records will
    # be updated and an error will never be raised.
    #
    # Options: 
    # * :if_exists => (:update | :error | :ignore)
    # * :db_adaptor => (<current db adaptor> | "ActiveRecord")
    #
    def create_or_update(records, keys, options = {})
      return if records.blank?
      keys = keys.respond_to?(:map) ? keys : [keys].compact
      options = DEFAULT_OPTIONS.merge(options)
      loader_class = self.const_get(options[:db_adaptor] + 'Loader')
      loader_class.new(self, options).create_or_update(records, keys)
    end

  end

  # ================================================================
  module InstanceMethods
  end

  # ================================================================
  class RecordNotUnique < StandardError ; end

  # ================================================================
  class BaseLoader

    def initialize(ar_class, options)
      @ar_class = ar_class
      @if_exists = options[:if_exists]
    end

    def create_or_update(records, keys)
      unless (keys.blank?)
        if (@if_exists == :update)
          update_existing_records(records, keys)
        elsif (@if_exists == :error)
          error_on_existing_records(records, keys)
        end
      end
      # insert new records
      insert_new_records(records, keys)
    end

    private
    # ================================================================
    # Methods below this line may be subclassed by individual loader
    # classes

    def update_existing_records(records, keys)
      update_command = make_update_command(records, keys)
      ActiveRecord::Base.connection.execute(update_command)
    end

    def error_on_existing_records(records, keys)
      count_query = make_count_query(records, keys)
      resp = ActiveRecord::Base.connection.select_one(count_query)
      count = resp["count"].to_i
      raise(RecordNotUnique, "found #{count} duplicate records") if (count > 0)
    end

    def insert_new_records(records, keys)
      insert_command = make_insert_command(records, keys)
      ActiveRecord::Base.connection.execute(insert_command)
    end

    # ================================================================
    # cross-vendor SQL queries

    # INSERT INTO table (column1, column2, ...)
    #      SELECT *
    #        FROM (candidates) AS candidates
    #   LEFT JOIN table AS incumbents
    #          ON incumbents.key1 = candidates.key1
    #         AND incumbents.key2 = candidates.key2
    #         AND incumbents.key3 = candidates.key3
    #       WHERE incumbents.column1 IS NULL
    #
    def make_insert_command(records, keys)
      sql_command = %{
INSERT INTO #{table_name} (#{mutable_column_names})
     SELECT candidates.*
       FROM (#{immediate_table(records)}) AS candidates
} +
        if (keys.blank?)
          ''
        else
          %{
  LEFT JOIN #{table_name} AS incumbents
         ON #{ keys.map {|k| "incumbents.#{k} = candidates.#{k}" }.join(' AND ') }
      WHERE incumbents.id IS NULL
}
        end
    end

    #     SELECT COUNT(*)
    #       FROM table
    # INNER JOIN (candidates) AS candidates
    #         ON incumbents.key1 = candidates.key1
    #        AND incumbents.key2 = candidates.key2
    #        ...
    def make_count_query(records, keys)
      sql_command = %{
    SELECT COUNT(*) AS count
      FROM #{table_name}
INNER JOIN (#{immediate_table(records)}) AS candidates
        ON #{ keys.map {|k| "#{table_name}.#{k} = candidates.#{k}"}.join(' AND ') }
}
    end
    
    # Create an ANSI-compliant SQL form directly from in-memory
    # records which, used as a sub-query, behaves like a table.
    # Example:
    #
    #       SELECT 2257 AS station_id, '2001-01-01' AS date, 22.5 AS temperature 
    # UNION SELECT 2257, '2001-01-02', 25.3
    # UNION SELECT 2257, '2001-01-03', 25.5
    #
    def immediate_table(records)
      columns = mutable_columns
      records.map {|r| immediate_row(columns, r, r == records[0]) }.join("\n")
    end

    def immediate_row(columns, row, is_first)
      (is_first ? '' : 'UNION ') +
        'SELECT ' +
        columns.map {|c| immediate_column(row.read_attribute(c.name), c) + (is_first ? " AS #{c.name}" : '')}.join(', ')
    end

    # Emit value in a database-compatible format.  created_at and
    # updated_at fields get special treatment.  Subclasses may need to
    # augment this generic form.  For the definition of quote(), see:
    #
    # usr/lib/ruby/gems/1.9.1/gems/activerecord-3.0.5/lib/active_record/connection_adapters/abstract/quoting.rb
    def immediate_column(value, column = nil)
      if ((column.name == 'created_at') && value.nil?) || (column.name == 'updated_at')
        value = Time.zone.now
      end
      ActiveRecord::Base.connection.quote(value, column)
    end

    # ================
    # helper fns

    def table_name
      @ar_class.table_name
    end

    def mutable_columns
      @ar_class.columns.reject {|c| c.primary }
    end

    def mutable_column_names(table_name = nil)
      (mutable_columns.map {|c| (table_name ? "#{table_name}." : '') + c.name}).join(', ')
    end


  end

  # ================================================================
  # ActiveRecordLoader uses the generic ActiveRecord methods.  Useful
  # as a fallback if your favorite vendor db isn't supported.

  class ActiveRecordLoader < BaseLoader

    def update_existing_records(records, keys)
      conditions = Hash[keys.map {|k| [k, nil]}]
      records.each do |r|
        set_conditions(conditions, r)
        incumbents = @ar_class.find(:all, :conditions => conditions)
        incumbents.each do |incumbent|
          incumbent.attributes = r.attributes
          incumbent.save(:validate => false)
        end
      end
    end

    def error_on_existing_records(records, keys)
      conditions = Hash[keys.map {|k| [k, nil]}]
      records.each do |r|
        set_conditions(conditions, r)
        raise(RecordNotUnique) if @ar_class.exists?(conditions)
      end
    end

    def insert_new_records(records, keys)
      unless (keys.blank?)
        conditions = Hash[keys.map {|k| [k, nil]}]
        records.each do |r|
          set_conditions(conditions, r)
          r.save(:validate => false) unless @ar_class.exists?(conditions)
        end
      else
        records.each {|r| r.save(:validate => false) }
      end
    end

    def set_conditions(conditions, record)
      conditions.each_key {|k| conditions.store(k, record.send(k))}
    end

  end

  # ================================================================
  # Support for MySQL
  class MySQLLoader < BaseLoader

    # MySQL
    # UPDATE table
    #   JOIN (candidates) AS candidates
    #    SET table.column1 = candidates.column1, table.column2 = candidates.column2, ...
    #  WHERE table.key1 = candidates.key1
    #    AND table.key2 = candidates.key2
    #    ...
    def make_update_command(records, keys)
      # Columns that are used for matching (keys) don't need to be updated
      update_column_names = mutable_columns.map {|c| c.name} - keys
      sql_command = %{
UPDATE #{table_name}
  JOIN (#{immediate_table(records)}) AS candidates
   SET #{update_column_names.map {|n| "#{table_name}.#{n} = candidates.#{n}"}.join(',')}
 WHERE #{ keys.map {|k| "#{table_name}.#{k} = candidates.#{k}"}.join(' AND ') }
}
    end

  end

  # ================================================================
  # Support for PostgreSQL
  class PostgreSQLLoader < BaseLoader

    # PostgreSQL
    # UPDATE table 
    #    SET (column1, column2, ...) = (candidates.column1, candidates.column2 ...)
    #   FROM (candidates) AS candidates
    #  WHERE table.key1 = candidates.key1
    #    AND table.key2 = candidates.key2
    #    ...
    def make_update_command(records, keys)
      sql_command = %{
UPDATE #{table_name}
   SET (#{mutable_column_names}) = (#{mutable_column_names('candidates')})
  FROM (#{immediate_table(records)}) AS candidates
 WHERE #{ keys.map {|k| "#{table_name}.#{k} = candidates.#{k}"}.join(' AND ') }
}
    end

    # PostgreSQL requires explicit casting of NULLs, timestamps and
    # strings: +x+ => +(CAST x AS <type>)+
    def immediate_column(value, column = nil)
      s = super(value, column)
      if column && (value.nil? || column.sql_type =~ /timestamp/ || column.sql_type =~ /character/)
        "CAST (#{s} AS #{column.sql_type})"
      else
        s
      end
    end

  end

  # ================================================================
  # Support for SQLite.  
  #
  # NB: We have not yet discovered a sensible SQLite implementation
  # for update_existing_records, so we use the ActiveRecord-only
  # version.  THIS IS SLOW compared to the native implementations.
  #
  class SQLiteLoader < BaseLoader

    # TODO: DRY this code, or better, replace it.
    def update_existing_records(records, keys)
      conditions = Hash[keys.map {|k| [k, nil]}]
      records.each do |r|
        set_conditions(conditions, r)
        incumbents = @ar_class.find(:all, :conditions => conditions)
        incumbents.each do |incumbent|
          incumbent.attributes = r.attributes
          incumbent.save(:validate => false)
        end
      end
    end

    # TODO: DRY this code, or better, replace it.
    def set_conditions(conditions, record)
      conditions.each_key {|k| conditions.store(k, record.send(k))}
    end

  end

end

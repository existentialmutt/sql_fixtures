module SqlFixtures
  class TableRefresher
    
    root_dir = Rails.root || Pathname.new(ENV["RAILS_ROOT"] || Dir.pwd)

    BASE_DIR = root_dir.join("spec", "db")
    STRUCTURE_DIR = BASE_DIR.join "structure"
    DATA_DIR = BASE_DIR.join "data"
    CONSTRAINTS_DIR = BASE_DIR.join "constraints"

    def refresh_tables! *tables_to_reload
      unless Rails.env.test?
        ActiveRecord::Base.establish_connection(Rails.configuration.database_configuration["test"])
      end
      all_tables = ActiveRecord::Base.connection.tables
      db_name = Rails.configuration.database_configuration["test"]["database"]

      # disable FK checks
      all_tables.each do |table|
        ActiveRecord::Base.connection.execute "ALTER TABLE #{table} DISABLE TRIGGER ALL;"
      end

      # reset the given tables
      tables_to_reload.each do |table|
        data_sql = DATA_DIR.join "#{table}.sql"

        ActiveRecord::Base.connection.execute %Q`DELETE FROM "#{table}";`
        system "psql #{db_name} < #{data_sql} > /dev/null"

        # TODO reset id sequences in case they're off
      end

      # re-enable FK checks
      all_tables.each do |table|
        ActiveRecord::Base.connection.execute "ALTER TABLE #{table} ENABLE TRIGGER ALL;"
      end
    ensure
      unless Rails.env.test?
        ActiveRecord::Base.establish_connection(Rails.configuration.database_configuration[Rails.env])
      end
    end

  end
end
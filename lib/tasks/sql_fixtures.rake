namespace "sql_fixtures" do
  desc "Start a server to edit test data"
  task :server do
    puts "Starting Server in test mode"
    exec "RAILS_ENV=test bin/rails server"
  end

  desc "Start a Rails console to edit test data"
  task :console do
    puts "Starting console in test mode"
    exec "RAILS_ENV=test bin/rails console"
  end

  desc "copy dev database to test database"
  task import_dev: :environment do
    dev_db_name = Rails.configuration.database_configuration["development"]["database"]
    test_db_name = Rails.configuration.database_configuration["test"]["database"]

    system "dropdb #{test_db_name}"
    system "createdb #{test_db_name}"

    exec "pg_dump #{dev_db_name} | psql #{test_db_name}"
  end

  desc "Export the test database to fixture files"
  task export: :environment do

    # TODO test or spec directory
    BASE_DIR = Rails.root.join("spec", "db")
    puts "exporting to #{BASE_DIR}"
    STRUCTURE_DIR = BASE_DIR.join "structure"
    DATA_DIR = BASE_DIR.join "data"
    CONSTRAINTS_DIR = BASE_DIR.join "constraints"

    RAILS_ENV = "test"
    database = Rails.configuration.database_configuration[RAILS_ENV]["database"]

    ActiveRecord::Base.establish_connection(Rails.configuration.database_configuration[RAILS_ENV])
    FileUtils.mkdir_p STRUCTURE_DIR
    FileUtils.mkdir_p DATA_DIR
    FileUtils.mkdir_p CONSTRAINTS_DIR

    # clear out any existing files
    FileUtils.rm Dir[STRUCTURE_DIR.join("*.sql")]
    FileUtils.rm Dir[DATA_DIR.join("*.sql")]
    FileUtils.rm Dir[CONSTRAINTS_DIR.join("*.sql")]

    # TODO exclude tables
    ActiveRecord::Base.connection.tables.each do |table|
      puts "exporting #{table}"
      structure_file = STRUCTURE_DIR.join "#{table}.sql"
      data_file = DATA_DIR.join "#{table}.sql"
      constraints_file = CONSTRAINTS_DIR.join "#{table}.sql"

      system "pg_dump #{database} -w -t #{table} --section=pre-data > #{structure_file}"
      system "pg_dump #{database} -w -t #{table} --section=data > #{data_file}"
      system "pg_dump #{database} -w -t #{table} --section=post-data > #{constraints_file}"
    end
  end

  desc "Load test database from fixture files"
  task load_all: :environment do
    BASE_DIR = Rails.root.join("spec", "db")
    STRUCTURE_DIR = BASE_DIR.join "structure"
    DATA_DIR = BASE_DIR.join "data"
    CONSTRAINTS_DIR = BASE_DIR.join "constraints"

    RAILS_ENV = "test"
    database = Rails.configuration.database_configuration[RAILS_ENV]["database"]

    puts "recreating database"
    system "dropdb #{database}"
    system "createdb #{database}"

    puts "loading struture"
    Dir[STRUCTURE_DIR.join("*.sql")].each do |file|
      system "psql #{database} < #{file} > /dev/null"
    end

    puts "loading data"
    Dir[DATA_DIR.join("*.sql")].each do |file|
      system "psql #{database} < #{file} > /dev/null"
    end

    puts "loading constraints"
    Dir[CONSTRAINTS_DIR.join("*.sql")].each do |file|
      system "psql #{database} < #{file} > /dev/null"
    end

  end


  desc "refresh data for individual tables from fixture files (specify with TABLES=table1,table2)"
  task refresh_tables: :environment do
    # TODO default to test environment if ENV['RAILS_ENV'] not set
    if Rails.env.production?
      raise "this task should not be run in production"
    end
    
    tables = ENV['TABLES']&.split(",")
    if tables.blank?
      raise "Please specify at lease one table in the TABLES environment variable"
    end

    SqlFixtures::TableRefresher.new.refresh_tables! *tables
  end


end
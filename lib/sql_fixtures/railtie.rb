class SqlFixtures::Railtie < Rails::Railtie
  rake_tasks do
    load 'tasks/sql_fixtures.rake'
  end
end
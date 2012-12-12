require 'active_record'
require 'yaml'

$:.unshift File.dirname(__FILE__)
require 'boot'

task :default => :migrate

desc "Migrate the database through scripts in db/migrate. Target specific version with VERSION=x"
task :migrate => :environment do
  ActiveRecord::Migrator.migrate('db/migrate', ENV["VERSION"] ? ENV["VERSION"].to_i : nil )
end

task :environment do
  Boot.boot!
  # ActiveRecord::Base.logger = Logger.new(File.open('tmp/database.log', 'a'))
end

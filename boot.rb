require 'erb'
require 'logger'

module Boot
  def self.boot!
    ENV['DATABASE_URL'] ||= 'postgres://pllhmannjudncf:Ps_3UxQoOwOHvtJc-EvPkri9ic@ec2-54-243-238-144.compute-1.amazonaws.com:5432/dfp7e26d8l7rdg'
    db = URI.parse(ENV['DATABASE_URL'] || 'http://localhost')
    if db.scheme == 'postgres' # This section makes Heroku work
      ActiveRecord::Base.establish_connection(
        :adapter  => db.scheme == 'postgres' ? 'postgresql' : db.scheme,
        :host     => db.host,
        :username => db.user,
        :password => db.password,
        :database => db.path[1..-1],
        :encoding => 'utf8'
      )
    else # And this is for my local environment
      environment = ENV['DATABASE_URL'] ? 'production' : 'development'
      db = YAML.load(ERB.new(File.read('config/database.yml')).result)[environment]
      ActiveRecord::Base.establish_connection(db)
    end
    ActiveRecord::Base.logger = Logger.new(STDOUT)
  end

  def self.clean_db!
    Record.destroy_all
  end
end

class AddHerokuAddresses < ActiveRecord::Migration
  def self.up
    create_table :heroku_addresses do |t|
      t.string :ip
    end
  end

  def self.down
    drop_table :heroku_addresses
  end
end

class CreateRecords < ActiveRecord::Migration
  def self.up
    create_table :records do |t|
      t.column :domain, :string, :null => false
      t.column :addresses, :binary, :null => false
      t.column :on_heroku, :boolean, default: false
    end
    add_index :records, :domain
  end

  def self.down
    drop_table :records
  end
end

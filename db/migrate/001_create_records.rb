class CreateRecords < ActiveRecord::Migration
  def self.up
    create_table :records do |t|
      t.column :domain, :string, :null => false
      t.column :addresses, :binary, :null => false
    end
  end

  def self.down
    drop_table :records
  end
end

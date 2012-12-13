class RemoveNotNullFromAddresses < ActiveRecord::Migration
  def self.up
    change_column :records, :addresses, :binary, null: true
  end

  def self.down
    change_column :records, :addresses, :binary, null: false
  end
end

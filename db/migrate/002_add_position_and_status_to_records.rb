class AddPositionAndStatusToRecords < ActiveRecord::Migration
  def self.up
    add_column :records, :position, :integer
    add_column :records, :status,   :string
  end

  def self.down
    drop_column :records, :status
    drop_column :records, :position
  end
end

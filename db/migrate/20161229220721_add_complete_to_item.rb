class AddCompleteToItem < ActiveRecord::Migration[5.0]
  def change
    add_column :items, :complete, :boolean, default: false
    add_column :items, :date_completed, :datetime
    add_column :items, :completed_by, :string
  end
end

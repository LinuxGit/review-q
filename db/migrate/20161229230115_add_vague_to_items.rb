class AddVagueToItems < ActiveRecord::Migration[5.0]
  def change
    add_column :items, :vague, :boolean, default: false
  end
end

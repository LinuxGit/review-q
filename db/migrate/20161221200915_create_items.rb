class CreateItems < ActiveRecord::Migration[5.0]
  def change
    create_table :items do |t|
      t.integer :channel_id
      t.integer :user_id
      t.string :ts
      t.string :message
      t.string :archive_link
    end
  end
end

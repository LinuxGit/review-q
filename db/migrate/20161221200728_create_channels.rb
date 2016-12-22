class CreateChannels < ActiveRecord::Migration[5.0]
  def change
    create_table :channels do |t|
      t.integer :team_id, required: true
      t.string :slack_channel_id, required: true
    end
  end
end

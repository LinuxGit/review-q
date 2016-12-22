class CreateTeams < ActiveRecord::Migration[5.0]
  def change
    create_table :teams do |t|
      t.string :name
      t.string :slack_id
      t.string :bot_slack_id
      t.string :bot_token
    end
  end
end

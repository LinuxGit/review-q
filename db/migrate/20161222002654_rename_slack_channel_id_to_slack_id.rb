class RenameSlackChannelIdToSlackId < ActiveRecord::Migration[5.0]
  def change
    rename_column :channels, :slack_channel_id, :slack_id
  end
end

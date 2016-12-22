class AddUserAvatar < ActiveRecord::Migration[5.0]
  def change
    add_column :users, :avatar_24, :string
  end
end

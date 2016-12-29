class Team < ActiveRecord::Base
  has_many :users
  has_many :channels

  validates :name, presence: true
  validates :bot_slack_id, uniqueness: true, presence: true
  validates :bot_token, uniqueness: true, presence: true

  def self.add_from_json(json_auth_res)
    p json_auth_res
    if json_auth_res["ok"]
      team = Team.find_or_initialize_by(slack_id: json_auth_res["team_id"])
      team.assign_attributes({
        name: json_auth_res["team_name"],
        bot_slack_id: json_auth_res["bot"]["bot_user_id"],
        bot_token: json_auth_res["bot"]["bot_access_token"]
      })

      if team.save!
        user = User.find_or_initialize_by(slack_id: json_auth_res["user_id"])
        user.assign_attributes(token: json_auth_res["access_token"], team: team)
        return true if user.save!
      end
    end

    return false
  end

  def create_channel_and_item_from_event(event)
    channel = create_channel(event.channel)

    if event.text.blank? && event.attachments && a = event.attachments.detect{ |a| a.is_share }
      user = users.find_or_create_by(slack_username: a.author_subname)
      item = channel.items.new(ts: event.ts, message: a.text, user: user, archive_link: a.from_url)
    else
      user = create_user(event.user)
      item = channel.items.new(ts: event.ts, message: event.text, user: user)
    end

    return item if item.save! && user.save!
  end

  def create_channel_from_event(event)
    channel = create_channel(event.channel)
    user = create_user(event.user)
    return channel if channel.save! && user.save!
  end

  def create_channel(channel_id)
    channels.find_or_create_by(slack_id: channel_id)
  end

  def create_user(user_id)
    users.find_or_create_by(slack_id: user_id)
  end
end

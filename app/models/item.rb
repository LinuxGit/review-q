class Item < ActiveRecord::Base
  belongs_to :channel
  belongs_to :user
  has_one :team, through: :channel

  before_validation :create_archive_link

  validates :ts, presence: true
  validates :archive_link, presence: true
  validates :user, presence: true

  def mark_complete(by_user_id)
    options = {
      token: team.bot_token,
      channel: user.slack_id,
      text: "#{archive_link} was marked as complete by <@#{by_user_id}>",
      as_user: true
    }

    res = RestClient.post 'https://slack.com/api/chat.postMessage', options, content_type: :json
  end

  def create_archive_link
    unless archive_link
      options = { token: team.bot_token }
      res = RestClient.post 'https://slack.com/api/team.info', options, content_type: :json
      domain = JSON.parse(res)["team"]["domain"]

      channel_name = if channel.type == :channel
                       options = { token: team.bot_token, channel: channel.slack_id }
                       res = RestClient.post 'https://slack.com/api/channels.info', options, content_type: :json
                       JSON.parse(res)["channel"]["name"]
                     else
                       channel.slack_id
                     end

      self.archive_link = "https://#{domain}.slack.com/archives/#{channel_name}/p#{ts.delete('.')}"
    end
  end
end

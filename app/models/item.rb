class Item < ActiveRecord::Base
  belongs_to :channel
  belongs_to :user
  has_one :team, through: :channel

  before_validation :create_archive_link

  validates :ts, presence: true
  validates :archive_link, presence: true
  validates :user, presence: true

  scope :open, -> { where(complete: false, vague: false) }

  def mark_complete(by_user_id)
    self.complete = true
    self.date_completed = Time.now
    self.completed_by = by_user_id
    self.save!

    if ENV['RACK_ENV'] == 'development' || by_user_id != user.slack_id
      options = {
        token: team.bot_token,
        channel: user.slack_id,
        as_user: true,
        text: "#{archive_link} was marked as complete by <@#{by_user_id}>",
      }

      res = RestClient.post 'https://slack.com/api/chat.postMessage', options, content_type: :json
    end

    options = {
      token: team.bot_token,
      channel: channel.slack_id,
      name: "white_check_mark",
      timestamp: ts
    }

    res = RestClient.post 'https://slack.com/api/reactions.add', options, content_type: :json
    p res.body

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

  def date_created
    Time.at(ts.split('.')[0].to_i)
  end

  def time_to_complete
    raise "Item not completed" unless complete
    date_completed - date_created
  end

  def time_to_complete_formatted
    t = time_to_complete
    Time.at(t).utc.strftime("%H:%M:%S")
  end

  def send_vague_message
    options = {
      token: team.bot_token,
      text: "Would you like to add this message to the queue?",
      channel: channel.slack_id,
      attachments: JSON.generate([{
        fallback: "FALLBACK",
        callback_id: "vague/" + id.to_s,
        actions: [
          {
            name: "yes",
            text: "Yes",
            type: "button",
            value: "yes"
          },
          {
            name: "no",
            text: "No",
            type: "button",
            value: "no"
          }
        ]
      }])
    }

    res = RestClient.post 'https://slack.com/api/chat.postMessage', options
  end

end

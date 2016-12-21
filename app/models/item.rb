require 'rest-client'

class Item
  attr_accessor :team, :user, :ts, :channel, :text, :archive_link

  def initialize(event, team)
    @team = team
    @ts = event.ts
    @channel = event.channel
    @text = event.text
    @archive_link = create_archive_link
    @user = fetch_user(event.user)
  end

  def type?
    case @channel[0]
    when 'C'
      :channel
    when 'G'
      :group
    when 'D'
      :im
    end
  end

  def mark_complete(by_user_id)
    options = {
      token: @team.bot["bot_access_token"],
      channel: @user["id"],
      text: "#{@archive_link} was marked as complete by <@#{by_user_id}>",
      as_user: true
    }

    res = RestClient.post 'https://slack.com/api/chat.postMessage', options, content_type: :json
  end

  def create_archive_link
    options = { token: @team.bot["bot_access_token"] }
    res = RestClient.post 'https://slack.com/api/team.info', options, content_type: :json
    domain = JSON.parse(res)["team"]["domain"]

    channel = if type? == :channel
      options = { token: @team.bot["bot_access_token"], channel: @channel }
      res = RestClient.post 'https://slack.com/api/channels.info', options, content_type: :json
      JSON.parse(res)["channel"]["name"]
    else
      @channel
    end

    "https://#{domain}.slack.com/archives/#{channel}/p#{@ts.delete('.')}"
  end

  def fetch_user(user_id)
    options = { token: @team.bot["bot_access_token"], user: user_id }
    res = RestClient.post 'https://slack.com/api/users.info', options, content_type: :json
    JSON.parse(res)["user"]
  end
end

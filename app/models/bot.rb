require 'resque'

class Bot
  def self.async_event_processing(data)
    Resque.enqueue(EventWorker, data)
  end

  def self.async_button_processing(data)
    Resque.enqueue(ButtonWorker, data)
  end

  def self.send_error_message(url)
    options = {
      response_type: "ephemeral",
      replace_original: false,
      text: "Sorry, that didn't work. Please try again."
    }

    res = RestClient.post url, JSON.generate(options), content_type: :json
  end

  def self.send_help_message(token, channel)
    options = {
      token: token,
      channel: channel,
      mrkdwn: true,
      attachments: JSON.generate([{
        mrkdwn_in: ["text"],
        fallback: "Required plain-text summary of the attachment.",
        color: Channel::PRIMARY_COLOR,
        title: "ReviewQ lets you build a queue of messages to review in a channel",
        text: "ReviewQ is a way to manage a queue of work within the context of a channel. For example, a legal team might queue up messages requesting them to review contracts. Software development team might queue up Pull Requests that need to be reviewed.\n\n :arrow_right: To get started, invite *@reviewq* to a channel."
        },
        {
          color: Channel::SECONDARY_COLOR,
          author_name: "Usage",
          mrkdwn_in: ["text", "fields"],
          fields: [
            {
              title: ":one: Add text to the queue",
              value: "`@reviewq add [text to add]`",
              short: true
            },
            {
              title: ":two: Show queue for a channel",
              value: "`@reviewq list`",
              short: true
            },
            {
              title: ":three: Add a message to the queue",
              value: "<https://get.slack.help/hc/en-us/articles/203274767-Share-messages-in-Slack|Share the message> and comment with `@reviewq add`",
              short: true
            },
            {
              title: ":four: Add a file to the queue",
              value: "Leave a comment with `@reviewq add` to an existing or new file",
              short: true
            }
          ]
        }
      ])
    }

    res = RestClient.post 'https://slack.com/api/chat.postMessage', options
    p res.body
  end

  def self.delete_message(channel, ts)
    options = {
      token: channel.team.bot_token,
      ts: ts,
      channel: channel.slack_id
    }

    res = RestClient.post 'https://slack.com/api/chat.delete', options
  end

end

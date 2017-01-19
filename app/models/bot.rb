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
      text: help_message,
      channel: channel,
      mrkdwn: true
    }

    res = RestClient.post 'https://slack.com/api/chat.postMessage', options
    p res.body
  end

  def self.help_message
    <<~HEREDOC
    *ReviewQ lets you queue up messages in a channel that need to be reviewed and dealt with*

     ReviewQ is a way to manage a queue of work within the context of a channel. For example, a legal team might queue up messages requesting them to review contracts. Software development team might queue up Pull Requests that need to be reviewed.

      *Add items to the queue easily*
      - Mention *@reviewq* in the channel and tell it what you want queued up: `@reviewq add [text you want to add]`
      - Add a file to the queue by leaving a comment that mentioned *@reviewq*
      - <https://get.slack.help/hc/en-us/articles/203274767-Share-messages-in-Slack|Share a message> and mention *@reviewq* to add the original message to the queue.

      View your review queue at any time by saying `@reviewq list`. When you mark items in the queue as complete, we'll notify the requestor to let them know it's done.

      Learn more at https://www.reviewqbot.com
    HEREDOC

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

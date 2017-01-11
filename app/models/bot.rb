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
      channel: channel
    }

    res = RestClient.post 'https://slack.com/api/chat.postMessage', options
    p res.body
  end

  def self.help_message
    <<~HEREDOC
    Review Q is a way to manage a queue of work within the context of a channel. For example, a legal team might queue up messages requesting them to review contracts or a software development team might queue up Pull Requests that need to be reviewed.

    To add a message to the queue for a channel just say `@review-q add [text you want to add]`.

    You can view your review queue at any time by saying `@review-q list`. From the list you can mark items as complete.

    We recommend using Slack's share message feature to take messages from the channel and add them to the queue (with some additional context for the person triaging the list).

    If you share a message and only say `@review-q add`, we'll automatically add just the text from the shared message to the queue.
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

class Channel < ActiveRecord::Base
  has_many :items
  belongs_to :team

  PER_PAGE = 3

  def type
    case slack_id[0]
    when 'C'
      :channel
    when 'G'
      :group
    when 'D'
      :im
    end
  end

  def send_summary_message(pre_message: '', url: 'https://slack.com/api/chat.postMessage')
    count = items.open.count
    item_pluralized = count > 1 ? 'items' : 'item'
    message = "#{pre_message}#{count} #{item_pluralized} in the queue"

    options = {
      token: team.bot_token,
      channel: slack_id,
      replace_original: true,
      text: message,
      attachments: [{
        fallback: "FALLBACK",
        callback_id: "all/" + slack_id,
        actions: [
          {
            name: "all",
            text: "View all",
            type: "button",
            value: "0"
          },
          {
            name: "close",
            text: "Close",
            type: "button",
            value: "close"
          }
        ]
      }]
    }

    if url == 'https://slack.com/api/chat.postMessage'
      options[:attachments] = JSON.generate(options[:attachments])
    else
      options = JSON.generate(options)
    end

    res = RestClient.post url, options, content_type: :json
  end

  def send_items_list(index, url = 'https://slack.com/api/chat.postMessage')
    return send_summary_message(url: url) if index == -1
    attachments = build_message_attachments(index)
    message = attachments.empty? ? "There are no messages in the queue" : "Here are your messages"

    options = {
      token: team.bot_token,
      channel: slack_id,
      replace_original: true,
      text: message,
    }

    if url == 'https://slack.com/api/chat.postMessage'
      options[:attachments] = JSON.generate(attachments)
    else
      options[:attachments] = attachments
      options = JSON.generate(options)
    end

    res = RestClient.post url, options, content_type: :json
  end

  def build_message_attachments(first)
    count = items.open.count
    return [] if count == 0

    last = first + (PER_PAGE - 1)
    last = count - 1 if last >= count
    p "#{first}, #{last}"
    attachments = items.open[first..last].inject([]) { |a, i| a << {
      author_name: i.user.first_name + " " + i.user.last_name,
      author_icon: i.user.avatar_24,
      color: "#95c0d8",
      text: i.message,
      footer: "<#{i.archive_link}|Archive link>",
      ts: i.ts,
      fallback: "Mark as done",
      callback_id: "complete_item/" + slack_id + "/" + first.to_s,
      mrkdwn_in: ["text"],
      actions: [{
        name: "complete",
        text: ":pencil: Mark as done",
        type: "button",
        value: i.ts
      }]
    } }

    buttons = []
    buttons << ["next", last + 1] if last != count - 1
    buttons << ["previous", first - PER_PAGE] if first != 0
    buttons << ["minimize", -1]

    actions = []
    buttons.each do |b|
      actions << {
        name: b[0],
        text: b[0].capitalize,
        type: "button",
        value: b[1]
      }
    end

    attachments << {
      color: "#4ead61",
      fallback: "Next/Previous",
      callback_id: "pagination/" + slack_id,
      actions: actions
    }
  end
end

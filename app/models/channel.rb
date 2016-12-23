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
    message = "#{pre_message}#{items.count} items in the queue"

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
    return [] if items.count == 0
    last = first + (PER_PAGE - 1)
    last = items.count - 1 if last >= items.count
    p "#{first}, #{last}"
    attachments = items[first..last].inject([]) { |a, i| a << {
      author_name: i.user.first_name + " " + i.user.last_name,
      author_icon: i.user.avatar_24,
      text: i.message,
      footer: "<#{i.archive_link}|Archive link>",
      ts: i.ts,
      fallback: "FALLBACK",
      callback_id: "complete_item/" + slack_id + "/" + first.to_s,
      actions: [{
        name: "complete",
        text: "Mark as done",
        type: "button",
        value: i.ts
      }]
    } }

    buttons = []
    buttons << ["next", last + 1] if last != items.count - 1
    buttons << ["previous", first - PER_PAGE] if first != 0
    buttons << ["close", -1]

    actions = []
    buttons.each do |b|
      actions << {
        name: b[0],
        text: b[0].capitalize + "/" + b[1].to_s,
        type: "button",
        value: b[1]
      }
    end

    attachments << {
      fallback: "FALLBACK",
      callback_id: "pagination/" + slack_id,
      actions: actions
    }
  end
end

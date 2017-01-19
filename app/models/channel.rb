class Channel < ActiveRecord::Base
  has_many :items
  belongs_to :team

  PER_PAGE = 3
  PRIMARY_COLOR = "#9469df"
  SECONDARY_COLOR = "#dbaaaa"

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
        color: PRIMARY_COLOR,
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

  def send_items_list(page_info, url = 'https://slack.com/api/chat.postMessage')
    page_info = page_info.split("/")
    index = page_info[0].to_i
    return send_summary_message(url: url) if index == -1

    reverse = page_info[1] == "true"

    attachments = build_message_attachments(index, reverse)

    message = if attachments.empty?
                "There are no messages in the queue"
              else
                if reverse
                  "Here are your messages (newest to oldest)"
                else
                  "Here are your messages (oldest to newest)"
                end
              end

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

  def build_message_attachments(first, reverse)
    count = items.open.count
    pages = (count.to_d / PER_PAGE).ceil
    current_page = (first.to_d / PER_PAGE).ceil + 1
    return [] if count == 0

    last = first + (PER_PAGE - 1)
    last = count - 1 if last >= count
    p "#{first}, #{last}"

    i = reverse ? items.open.reverse : items.open

    attachments = i[first..last].inject([]) { |a, i| a << {
      author_name: i.user.full_name,
      author_icon: i.user.avatar_24,
      color: SECONDARY_COLOR,
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
    buttons << ["next", last + 1, reverse] if last != count - 1
    buttons << ["previous", first - PER_PAGE, reverse] if first != 0
    buttons << ["minimize", -1, reverse]
    buttons << ["sort", 0, !reverse] if first == 0

    actions = []
    buttons.each do |b|
      actions << {
        name: b[0],
        text: b[0].capitalize,
        type: "button",
        value: "#{b[1]}/#{b[2]}"
      }
    end

    attachments << {
      color: PRIMARY_COLOR,
      fallback: "Next/Previous",
      callback_id: "pagination/" + slack_id,
      footer: "Page #{current_page} of #{pages}",
      actions: actions
    }
  end

  def send_vague_message(item)
    options = {
      token: team.bot_token,
      text: "Would you like to add this message to the queue?",
      channel: slack_id,
      attachments: JSON.generate([{
        fallback: "FALLBACK",
        callback_id: "vague/" + item.id.to_s,
        color: PRIMARY_COLOR,
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
    p res.body
  end
end

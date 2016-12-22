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


  def build_message_attachments(first)
    return [] if items.count == 0
    last = first + (PER_PAGE - 1)
    last = items.count - 1 if last >= items.count
    p "#{first}, #{last}"
    attachments = items[first..last].inject([]) { |a, i| a << {
      author_name: i.user.first_name + " " + i.user.last_name,
      #author_icon: i.user['profile']['image_24'],
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

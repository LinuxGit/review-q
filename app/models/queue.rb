class Queue
  attr_accessor :items

  PER_PAGE = 3

  def initialize
    @items = []
  end

  def add(item)
    @items << item
  end

  def remove(item)
    @items.delete(item)
  end

  def find(ts)
    @items.select { |i| i.ts == ts }
  end

  def build_message_attachments(first)
    return [] if @items.empty?
    last = first + (PER_PAGE - 1)
    last = @items.length - 1 if last >= @items.length
    p "#{first}, #{last}"
    attachments = @items[first..last].inject([]) { |a, i| a << {
      author_name: i.user['profile']['first_name'] + " " + i.user['profile']["last_name"],
      author_icon: i.user['profile']['image_24'],
      text: i.text,
      footer: "<#{i.archive_link}|Archive link>",
      ts: i.ts,
      fallback: "FALLBACK",
      callback_id: "complete_item/" + channel + "/" + first.to_s,
      actions: [{
        name: "complete",
        text: "Mark as done",
        type: "button",
        value: i.ts
      }]
    } }

    buttons = []
    buttons << ["next", last + 1] if last != @items.length - 1
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
      callback_id: "pagination/" + channel,
      actions: actions
    }
  end

  private
  def channel
    @items.last.channel
  end
end

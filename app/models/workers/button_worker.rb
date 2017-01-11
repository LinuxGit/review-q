class ButtonWorker
  @queue = :events

  def self.perform(resque_data)
    data = JSON.parse(resque_data, object_class: OpenStruct)

    @team = Team.find_by(slack_id: data.team.id)
    callback_ids = data.callback_id.split('/')

    case callback_ids[0]
    when "complete_item"
      item = Item.find_by(ts: data.actions[0]["value"])
      if item
        item.mark_complete(data.user["id"])
        item.channel.send_items_list(callback_ids[2], data.response_url)
      else
        Bot.send_error_message(data.response_url)
      end

    when "vague"
      item = Item.find(callback_ids[1])
      if item
        if data.actions[0]["value"] == "yes"
          item.vague = false
          item.save
          item.channel.send_summary_message(pre_message: ":white_check_mark: Item added! There are now ", url: data.response_url)
        else
          item.destroy!
          options = {
            replace_original: true,
            text: "Got it! I'll ignore that message."
          }

          res = RestClient.post data.response_url, JSON.generate(options), content_type: :json
        end
      end

    end
  end
end


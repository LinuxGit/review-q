class EventWorker
  @queue = :events

  def self.perform(resque_data)
    data = JSON.parse(resque_data, object_class: OpenStruct)
    p data

    if data.type == "event_callback"
      event = data.event
      p event

      @team = Team.find_by(slack_id: data.team_id)

      raise "team not found #{data.team_id}" unless @team
      p "Team found: #{@team.name}"

      if event.type == "message"
        case event.subtype
        when nil

          case event.text
          when /^<@#{@team.bot_slack_id}> add/
            add_item(event, event.text)

          when /^<@#{@team.bot_slack_id}> list/
            channel = Channel.find_by(slack_id: event.channel)

            if !channel
              channel = @team.create_channel_from_event(event)
            end

            channel.send_items_list("0")

          when /^<@#{@team.bot_slack_id}> help/
            Bot.send_help_message(@team.bot_token, event.channel)

          when /<@#{@team.bot_slack_id}>/
            add_item(event, event.text,  vague: true)

          when 'help', 'list', 'add', 'hi', 'hello'
            if event.channel[0] == 'D'
              Bot.send_help_message(@team.bot_token, event.channel)
            end
          else
            p "Message not related to Review Q"
          end

        when "file_comment"
          if event.comment.comment.match /^<@#{@team.bot_slack_id}> add/
            add_item(event, event.comment.comment)
          end

        when "file_share"
          if event.file.initial_comment.comment.match /^<@#{@team.bot_slack_id}> add/
              add_item(event, event.file.initial_comment.comment)
          end
        end
      end
    end
  end

  def self.add_item(event, message, vague: false)
    p "Message received: #{message}"

    item = @team.create_channel_and_item_from_event(event, message)
    if vague
      item.channel.send_vague_message(item)
    else
      item.channel.send_summary_message(pre_message: "Item added! :white_check_mark:\nThere are now ")
    end
  end
end

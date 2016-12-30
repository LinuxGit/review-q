require 'rest-client'
require 'sinatra/base'
require 'sinatra/activerecord'
require 'json'

Dir["app/models/*.rb"].each {|file| require_relative file }

class MyApp < Sinatra::Base
  register Sinatra::ActiveRecordExtension

  ActiveRecord::Base.establish_connection(ENV['DATABASE_URL'] || 'postgres://localhost/review-q_dev')

  get '/' do
    erb :index
  end

  get '/oauth' do
    if params['code']

      options = {
        client_id: ENV['SLACK_CLIENT_ID'],
        client_secret: ENV['SLACK_CLIENT_SECRET'],
        code: params['code']
      }

      res = RestClient.post 'https://slack.com/api/oauth.access', options, content_type: :json
      if Team.add_from_json(JSON.parse(res))
        "Bot successfully installed"
      else
        "Oh no :( Something went wrong. The error message is: #{JSON.parse(res)['error']}. Hope that means something to you."
      end
    end
  end

  post '/events' do
    request.body.rewind
    data = JSON.parse(request.body.read, object_class: OpenStruct)

    halt 500 if data.token != ENV['VERIFICATION_TOKEN']

    if data.type == "url_verification"
      content_type :json
      return {challenge: data.challenge}.to_json

    elsif data.type == "event_callback"
      event = data.event
      p event

      @team = Team.find_by(slack_id: data.team_id)

      halt 500 unless @team

      case event.type
      when "message"
        if !event.subtype || event.subtype && event.subtype != "message_deleted"
          case event.text
          when /^<@#{@team.bot_slack_id}> add/
            p "Team found: #{@team.name}"
            p "Message received: #{event.text}"

            t = Thread.new {
              event.text.gsub!("<@#{@team.bot_slack_id}> add", '').strip!
              item = @team.create_channel_and_item_from_event(event)
              item.channel.send_summary_message(pre_message: "Item added! :white_check_mark:\nThere are now ")
            }

          when /^<@#{@team.bot_slack_id}> list/
            p "Team found: #{@team.name}"
            p "Message received: #{event.text}"

            channel = Channel.find_by(slack_id: event.channel)

            if !channel
              channel = @team.create_channel_from_event(event)
            end

            channel.send_items_list(0)

          when /^<@#{@team.bot_slack_id}> help/
            Bot.send_help_message(@team.bot_token, event.channel)

          when /^<@#{@team.bot_slack_id}>/
            t = Thread.new {
              event.text.gsub!("<@#{@team.bot_slack_id}>", '').strip!
              item = @team.create_channel_and_item_from_event(event, vague: true)
              item.send_vague_message
            }

          when 'help'
            if event.channel[0] == 'D'
              Bot.send_help_message(@team.bot_token, event.channel)
            end
          else
            p "Message not related to Review Q"
          end
        end


        return 200
      end
    end
  end

  post '/interactive-button' do
    request.body.rewind
    body_arr = URI::decode_www_form(request.body.read)
    data = JSON.parse(body_arr[0][1], object_class: OpenStruct)

    halt 500 if data.token != ENV['VERIFICATION_TOKEN']

    @team = Team.find_by(slack_id: data.team.id)
    callback_ids = data.callback_id.split('/')

    case callback_ids[0]
    when "all", "pagination"
      channel = Channel.find_by(slack_id: callback_ids[1])

      if channel
        Bot.delete_message(channel, data.message_ts) if data.actions[0]["value"] == "close"
        channel.send_items_list(data.actions[0]["value"].to_i, data.response_url)
      else
        Bot.send_error_message(data.response_url)
      end

    when "complete_item"
      item = Item.find_by(ts: data.actions[0]["value"])
      Thread.new {
        if item
          item.mark_complete(data.user["id"])
          item.channel.send_items_list(callback_ids[2].to_i, data.response_url)
        else
          Bot.send_error_message(data.response_url)
        end
      }

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

    return 200
  end
end

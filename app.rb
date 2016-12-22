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

    case data.type
    when "url_verification"
      content_type :json
      return {challenge: data.challenge}.to_json

    when "event_callback"
      event = data.event
      @team = Team.find_by(slack_id: data.team_id)
      if @team && event.text && event.text.match(/<@#{@team.bot_slack_id}>/)
        p "Team found: #{@team.name}"
        p "Message received: #{event.text}"
        t = Thread.new {

          item = @team.create_channel_and_item_from_event(event)

          options = {
            token: @team.bot_token,
            channel: item.channel.slack_id,
            text: "#{item.channel.items.count} items in the queue",
            attachments: JSON.generate([{
              fallback: "FALLBACK",
              callback_id: "all/" + event.channel,
              actions: [
                {
                  name: "all",
                  text: "View all",
                  type: "button",
                  value: "0"
                }
              ]
            }])
          }

          res = RestClient.post 'https://slack.com/api/chat.postMessage', options, content_type: :json
        }

        t.abort_on_exception = true
        return 200
      else
        if !@team
          p "No team found"
        else
          p "Message not related to Review Q"
        end
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
        page_item_index = data.actions[0]["value"].to_i
        attachments = channel.build_message_attachments(page_item_index)

        options = {
          replace_original: true,
          text: "Here are your messages",
          attachments: attachments
        }

      else
        options = {
          response_type: "ephemeral",
          replace_original: false,
          text: "Sorry, that didn't work. Please try again."
        }

      end
      res = RestClient.post data.response_url, JSON.generate(options), content_type: :json

    when "complete_item"
      channel = Channel.find_by(slack_id: callback_ids[1])

      if channel
        item = Item.find_by(ts: data.actions[0]["value"])
        if item
          item.mark_complete(data.user["id"])
          item.destroy
          attachments = channel.build_message_attachments(callback_ids[2].to_i)
          message = attachments.empty? ? "There are no messages in the queue" : "Here are your messages"

          options = {
            replace_original: true,
            text: message,
            attachments: attachments
          }
        end

      else
        options = {
          response_type: "ephemeral",
          replace_original: false,
          text: "Sorry, that didn't work. Please try again."
        }

      end
      res = RestClient.post data.response_url, JSON.generate(options), content_type: :json

    end

    return 200
  end
end

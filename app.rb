require 'rest-client'
require 'sinatra'
require 'json'

Dir["app/models/*.rb"].each {|file| require_relative file }

def initialize
  super()
  @teams = Teams.new
  @queues = Queues.new
end

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
    @teams.add!(JSON.parse(res))

    @teams.all.to_s
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
    @team = @teams.find(data.team_id, event.user)
    if event.text && event.text.match(/<@#{@team.bot["bot_user_id"]}>/)
      t = Thread.new {
        item = Item.new(event, @team)
        q = @queues.find_or_add(event.channel)
        q.add item

        options = {
          token: @team.bot["bot_access_token"],
          channel: event.channel,
          text: "#{q.items.length} items in the queue",
          attachments: JSON.generate([{
            fallback: "FALLBACK",
            callback_id: "all/" + event.channel,
            actions: [
                {
                    name: "all",
                    text: "View all",
                    type: "button",
                    value: "all"
                }
            ]
          }])
        }

        res = RestClient.post 'https://slack.com/api/chat.postMessage', options, content_type: :json
      }

      t.abort_on_exception = true
      return 200
    end
  end
end

post '/interactive-button' do
  request.body.rewind
  body_arr = URI::decode_www_form(request.body.read)
  data = JSON.parse(body_arr[0][1], object_class: OpenStruct)

  halt 500 if data.token != ENV['VERIFICATION_TOKEN']

  @team = @teams.find(data.team.id, data.user.id)
  callback_ids = data.callback_id.split('/')
  case callback_ids[0]
  when 'all'
    q = @queues.find(callback_ids[1])
    if q
      attachments = q.build_message_attachments(0)

      options = {
        response_type: "ephemeral",
        text: "Here are your messages",
        replace_original: false,
        attachments: attachments
      }

      res = RestClient.post data.response_url, JSON.generate(options), content_type: :json
    else
      options = {
        response_type: "ephemeral",
        replace_original: false,
        text: "Sorry, that didn't work. Please try again."
      }

      res = RestClient.post data.response_url, JSON.generate(options), content_type: :json
    end

  when "pagination"
    q = @queues.find(callback_ids[1])
    if q
      val = data.actions[0]["value"].to_i
      attachments = q.build_message_attachments(val)

      options = {
        response_type: "ephemeral",
        text: "Here are your messages",
        replace_original: true,
        attachments: attachments
      }

      res = RestClient.post data.response_url, JSON.generate(options), content_type: :json
    end
  end



  return 200
end

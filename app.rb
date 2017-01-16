require 'rest-client'
require 'sinatra/base'
require 'sinatra/activerecord'
require 'json'

Dir["app/models/**/*.rb"].each {|file| require_relative file }

class MyApp < Sinatra::Base
  register Sinatra::ActiveRecordExtension

  set :public_folder, 'public'
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
    body = request.body.read

    data = JSON.parse(body)
    halt 500 if data["token"] != ENV['VERIFICATION_TOKEN']

    if data["type"] == "url_verification"
      content_type :json
      return {challenge: data["challenge"]}.to_json
    end

    Bot.async_event_processing(body)

    return 200
  end

  post '/interactive-button' do
    request.body.rewind
    body_arr = URI::decode_www_form(request.body.read)
    data = JSON.parse(body_arr[0][1], object_class: OpenStruct)

    halt 500 if data["token"] != ENV['VERIFICATION_TOKEN']

    callback_ids = data.callback_id.split('/')
    if callback_ids[0] == "all" || callback_ids[0] == "pagination"
      channel = Channel.find_by(slack_id: callback_ids[1])

      if channel
        Bot.delete_message(channel, data.message_ts) if data.actions[0]["value"] == "close"
        channel.send_items_list(data.actions[0]["value"], data.response_url)
      else
        Bot.send_error_message(data.response_url)
      end
    else
      Bot.async_button_processing(body_arr[0][1])
    end

    return 200
  end
end

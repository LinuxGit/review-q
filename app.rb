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

        case event.text
        when /^<@#{@team.bot_slack_id}> add/
          p "Team found: #{@team.name}"
          p "Message received: #{event.text}"

          event.text.gsub!("<@#{@team.bot_slack_id}> add", '').strip!
          item = @team.create_channel_and_item_from_event(event)
          item.channel.send_summary_message(pre_message: "Item added! There are now ")

        when /^<@#{@team.bot_slack_id}> list/
          p "Team found: #{@team.name}"
          p "Message received: #{event.text}"

          channel = Channel.find_by(slack_id: event.channel)

          if !channel
            channel = @team.create_channel_from_event(event)
          end

          channel.send_items_list(0)

        when /^<@#{@team.bot_slack_id}> help/
          send_help_message(@team.bot_token, event.channel)

        when 'help'
          if event.channel[0] == 'D'
            send_help_message(@team.bot_token, event.channel)
          end
        else
          p "Message not related to Review Q"
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
        channel.send_items_list(data.actions[0]["value"].to_i, data.response_url)
      else
        send_error_message(data.response_url)
      end

    when "complete_item"
      item = Item.find_by(ts: data.actions[0]["value"])
      if item
        item.mark_complete(data.user["id"])
        item.destroy
        item.channel.send_items_list(callback_ids[2].to_i, data.response_url)
      else
        send_error_message(data.response_url)
      end
    end

    return 200
  end

  def send_error_message(url)
    options = {
      response_type: "ephemeral",
      replace_original: false,
      text: "Sorry, that didn't work. Please try again."
    }

    res = RestClient.post url, JSON.generate(options), content_type: :json
  end

  def send_help_message(token, channel)
    options = {
      token: token,
      text: help_message,
      channel: channel
    }

    res = RestClient.post 'https://slack.com/api/chat.postMessage', options
    p res.body
  end

  def help_message
    <<~HEREDOC
    Review Q is a way to manage a queue of work within the context of a channel. For example, a legal team might queue up messages requesting them to review contracts or a software development team might queue up Pull Requests that need to be reviewed.

    To add a message to the queue for a channel just say `@review-q add [text you want to add]`.

    You can view your review queue at any time by saying `@review-q list`. From the list you can mark items as complete.

    We recommend using Slack's share message feature to take messages from the channel and add them to the queue (with some additional context for the person triaging the list).

    If you share a message and only say `@review-q add`, we'll automatically add just the text from the shared message to the queue.
    HEREDOC

  end
end

class User < ActiveRecord::Base
  belongs_to :team
  has_many :items

  before_save :fetch_name

  def fetch_name
    if first_name.blank? && last_name.blank?
      options = {token: team.bot_token, user: slack_id}
      res = RestClient.post 'https://slack.com/api/users.info', options, content_type: :json
      parsed_res = JSON.parse(res)
      if parsed_res["ok"]
        self.first_name = parsed_res["user"]["profile"]["first_name"]
        self.last_name = parsed_res["user"]["profile"]["last_name"]
      end
    end
  end
end

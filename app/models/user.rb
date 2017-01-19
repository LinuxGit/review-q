class User < ActiveRecord::Base
  belongs_to :team
  has_many :items

  validates :slack_username, presence: true
  validates :slack_id, uniqueness: true, presence: true

  before_validation :fetch_missing_info

  def full_name
    if first_name
      first_name + " " + last_name
    else
      slack_username
    end
  end

  def fetch_missing_info
    if slack_id.blank?
      options = {token: team.bot_token}
      res = RestClient.post 'https://slack.com/api/users.list', options, content_type: :json
      parsed_res = JSON.parse(res)
      if parsed_res["ok"]
        user = parsed_res["members"].detect { |u| u["name"] == self.slack_username }
        if user
          self.slack_id   = user["id"]
          self.avatar_24  = user["profile"]["image_24"]
          self.first_name = user["profile"]["first_name"]
          self.last_name  = user["profile"]["last_name"]
        end
      end
    end

    if (first_name.blank? && last_name.blank?) || slack_username.blank? || avatar_24.blank?
      options = {token: team.bot_token, user: slack_id}
      res = RestClient.post 'https://slack.com/api/users.info', options, content_type: :json
      parsed_res = JSON.parse(res)
      if parsed_res["ok"]
        self.slack_username = parsed_res["user"]["name"]
        self.avatar_24  = parsed_res["user"]["profile"]["image_24"]
        self.first_name = parsed_res["user"]["profile"]["first_name"] || parsed_res["user"]["name"]
        self.last_name  = parsed_res["user"]["profile"]["last_name"]
      end
    end
  end
end

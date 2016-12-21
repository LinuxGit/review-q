require 'json'

class Teams

  def initialize
    @teams = if FileTest.exist?("store.json")
      JSON.parse(File.read('store.json'))
    else
      []
    end
  end

  def all
    @teams
  end

  def add(team)
    @teams << team
  end

  def save
    File.open("store.json","w") do |file|
      file.write @teams.to_json
    end
  end

  def add!(team)
    add(team)
    save
  end

  def find(team_id, user_id)
    all_matching_auths = @teams.select {|t| t["team_id"] == team_id }
    user_auth = all_matching_auths.detect {|t| t["user_id"] == user_id }
    team = user_auth || all_matching_auths.first

    team ? OpenStruct.new(team) : nil
  end
end

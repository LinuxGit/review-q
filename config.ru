require './app'
require 'resque/server'

run Rack::URLMap.new \
  "/"       => MyApp,
  "/resque" => Resque::Server.new

require "./app"
require 'resque/tasks'
require 'sinatra/activerecord/rake'

task "setup" => :environment do
  ENV['QUEUE'] = '*'
  ENV['TERM_CHILD'] = '1'
  ENV['RESQUE_TERM_TIMEOUT'] = '10'
end

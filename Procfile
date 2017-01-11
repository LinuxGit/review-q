web: bundle exec rackup config.ru -p $PORT
resque: env TERM_CHILD=1 QUEUE=* bundle exec rake resque:work

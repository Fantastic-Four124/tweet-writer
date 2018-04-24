# server.rb
require 'sinatra'
require 'mongoid'
require 'mongoid_search'
require 'byebug'
require 'json'
require 'sinatra/cors'
require_relative 'models/tweet'
require 'redis'
require 'rest-client'
require_relative 'writer_client.rb'
require 'newrelic_rpm'

#writer_client = WriterClient.new('writer_queue',ENV["RABBITMQ_BIGWIG_RX_URL"])

# Thread.new do
#   require_relative 'writer_server.rb'
# end


# DB Setup
Mongoid.load! "config/mongoid.yml"


enable :sessions

set :bind, '0.0.0.0' # Needed to work with Vagrant
set :port, 8085

set :allow_origin, '*'
set :allow_methods, 'GET,HEAD,POST'
set :allow_headers, 'accept,content-type,if-modified-since'
set :expose_headers, 'location,link'

configure do
  tweet_uri = URI.parse(ENV["TWEET_REDIS_URL"])
  user_uri = URI.parse(ENV['USER_REDIS_URL'])
  follow_uri = URI.parse(ENV['FOLLOW_REDIS_URL'])
  tweet_uri_spare = URI.parse(ENV['TWEET_REDIS_SPARE_URL'])
  $tweet_redis_spare = Redis.new(:host => tweet_uri_spare.host, :port => tweet_uri_spare.port, :password => tweet_uri_spare.password)
  $tweet_redis = Redis.new(:host => tweet_uri.host, :port => tweet_uri.port, :password => tweet_uri.password)
  $follow_redis = Redis.new(:host => follow_uri.host, :port => follow_uri.port, :password => follow_uri.password)
  $user_redis = Redis.new(:host => user_uri.host, :port => user_uri.port, :password => user_uri.password)
end

helpers do
  def cache(redis, redis_key, json_tweet)
    redis.lpush(redis_key, json_tweet)
    if redis.llen(redis_key) > 50
      redis.rpop(redis_key)
    end
  end
end

# These are still under construction.

get '/loaderio-3790352c0664df3f597575d62a09d082.txt' do
  send_file 'loaderio-3790352c0664df3f597575d62a09d082.txt'
end

get '/loaderio-5e6733da8faf19acc30234ffdc8ed34d.txt' do
  send_file 'loaderio-5e6733da8faf19acc30234ffdc8ed34d.txt'
end
#
post '/api/v1/:apitoken/tweets/new' do
  if !$user_redis.get(params[:apitoken]).nil?
    # byebug
    username = JSON.parse($user_redis.get(params[:apitoken]))["username"]
    user_id = JSON.parse($user_redis.get(params[:apitoken]))["id"].to_i
    mentions = []
    # uncertain = []
    # content = params["tweet-input"].split # Tokenizes the message
    # content.each do |token|
    #   if /([@.])\w+/.match(token)
    #     term = token[1..-1]
    #     if !$user_redis.get(term).nil?
    #       mentions << {term => $user_redis.get(term)}
    #     else
    #       uncertain << term
    #     end
    #   end
    # end
    # mentions = mentions + JSON.parse(RestClient.get 'https://nanotwitter-userservice.herokuapp.com/api/v1/users/exists', {usernames: uncertain.to_json})
    result = Hash.new
    tweet = Tweet.new(
      contents: params["tweet-input"],
      date_posted: Time.now,
      user: {username: username,
      id: user_id
    },
      mentions: mentions
    )
    # Redis block
    # puts tweet.to_json
    cache($tweet_redis, "recent", tweet.to_json)
    cache($tweet_redis_spare, "recent", tweet.to_json)
    cache($tweet_redis, user_id.to_s + "_feed", tweet.to_json)
    cache($tweet_redis_spare, user_id.to_s + "_feed", tweet.to_json)
    if !$follow_redis.get("#{user_id.to_s} followers").nil?
      JSON.parse($follow_redis.get("#{user_id.to_s} followers")).keys.each do |follower|
        cache($tweet_redis,follower.to_s + "_timeline", tweet.to_json)
        cache($tweet_redis_spare,follower.to_s + "_timeline", tweet.to_json)
      end
    end

    # byebug
    #thr = Thread.new{ writer_client.call(tweet.to_json) }
    $writer_client.call(tweet.to_json)
    #saved = tweet.save
    # puts tweet.to_json
    return {err: false}.to_json
  end
  {err: true}.to_json
end

# ONLY TO BE USED FOR TESTING
delete '/api/v1/tweets/delete' do
  $tweet_redis.flushall
  $tweet_redis_spare.flushall
  success = Tweet.delete_all
  success.to_json
end

post '/testing/tweets/new' do
  puts params
  username = params[:username]
  user_id = params[:id]
  mentions = []
  # uncertain = []
  # content = msg.split # Tokenizes the message
  # content.each do |token|
  #   if /([@.])\w+/.match(token)
  #     term = token[1..-1]
  #     if !$user_redis.get(term).nil?
  #       mentions << {term => $user_redis.get(term)}
  #     else
  #       uncertain << term
  #     end
  #   end
  # end
  # mentions = mentions + JSON.parse(RestClient.get 'https://nanotwitter-userservice.herokuapp.com//api/v1/users/exists', {usernames: uncertain.to_json})
  result = Hash.new
  tweet = Tweet.new(
    contents: params["tweet-input"],
    date_posted: Time.now,
    user: {username: username,
    id: user_id
  },
    mentions: mentions
  )
  puts tweet.to_json
  cache($tweet_redis, "recent", tweet.to_json)
  cache($tweet_redis_spare, "recent", tweet.to_json)
  cache($tweet_redis, user_id.to_s + "_feed", tweet.to_json)
  cache($tweet_redis_spare, user_id.to_s + "_feed", tweet.to_json)
  if !$follow_redis.get("#{user_id.to_s} followers").nil?
    JSON.parse($follow_redis.get("#{user_id.to_s} followers")).keys.each do |follower|
      cache($tweet_redis, "#{follower}_timeline", tweet.to_json)
      cache($tweet_redis_spare, "#{follower}_timeline", tweet.to_json)
    end
  end
#thr = Thread.new{ writer_client.call(tweet.to_json) }
  $writer_client.call(tweet.to_json)
  #saved = tweet.save
  # puts tweet.to_json
  return {err: false}.to_json
end

delete '/api/v1/tweets/delete/:user_id' do
  success = Tweet.delete_all(:user_id => params[:user_id])
  $tweet_redis.delete(params[:user_id] + "_feed")
  $tweet_redis_spare.delete(params[:user_id] + "_feed")
  success.to_json
end

post '/api/v1/tweets/bulkinsert' do
  batch = []
  i = 0
  tweet_feed = JSON.parse(params["tweets"])
  tweet_feed.each do |tweet|
    if tweet["mentions"].nil?
      mentions = []
    else
      mentions = tweet["mentions"]
    end
    entry = {
      contents: tweet["tweet-input"],
      date_posted: Time.now,
      user: {
        username: tweet["username"],
        id: tweet["id"]
      },
      mentions: mentions
    }
    batch << entry
    # if i < 50:
    #   cache($tweet_redis, "recent", entry.to_json)
    #   cache($tweet_redis_spare, "recent", entry.to_json)
    #   i++
    # end
  end
  Tweet.collection.insert_many(batch)
end

end

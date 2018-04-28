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

# DB Setup
Mongoid.load! "config/mongoid.yml"
$user_exists = 'https://nanotwitter-userservice.herokuapp.com/api/v1/users/exists'


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
  tweet_uri_3 = URI.parse(ENV['TWEET_REDIS_3'])
  $tweet_redis_spare = Redis.new(:host => tweet_uri_spare.host, :port => tweet_uri_spare.port, :password => tweet_uri_spare.password)
  $tweet_redis = Redis.new(:host => tweet_uri.host, :port => tweet_uri.port, :password => tweet_uri.password)
  $tweet_redis_3 = Redis.new(:host => tweet_uri_3.host, :port => tweet_uri_3.port, :password => tweet_uri_3.password)
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

  def add_to_redis_list(name,tweet)
    cache($tweet_redis, name, tweet.to_json)
    cache($tweet_redis_spare, name, tweet.to_json)
    cache($tweet_redis_3, name, tweet.to_json)
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
  session = $user_redis.get(params[:apitoken])
  if !session.nil?
    username = JSON.parse(session)["username"]
    user_id = JSON.parse(session)["id"].to_i
    mentions = JSON.parse(params[:mentions])
    mentions = validate(mentions) if !mentions.empty?
    result = Hash.new
    tweet = Tweet.new(
      contents: params["tweet-input"],
      date_posted: Time.now,
      user: {username: username,
      id: user_id
    },
      mentions: mentions
    )
    add_to_redis_list("recent",tweet)
    add_to_redis_list(user_id.to_s + "_feed",tweet)
    if !$follow_redis.get("#{user_id.to_s} followers").nil?
      JSON.parse($follow_redis.get("#{user_id.to_s} followers")).keys.each do |follower|
        add_to_redis_list(follower.to_s + "_timeline",tweet)
      end
    end

    $writer_client.call(tweet.to_json)
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
  username = params[:username]
  user_id = params[:id]
  mentions = []
  result = Hash.new
  tweet = Tweet.new(
    contents: params["tweet-input"],
    date_posted: Time.now,
    user: {username: username,
    id: user_id
  },
    mentions: mentions
  )
  add_to_redis_list("recent",tweet)
  add_to_redis_list(user_id.to_s + "_feed",tweet)
  if !$follow_redis.get("#{user_id.to_s} followers").nil?
    JSON.parse($follow_redis.get("#{user_id.to_s} followers")).keys.each do |follower|
      add_to_redis_list(follower.to_s + "_timeline",tweet)
    end
  end
  $writer_client.call(tweet.to_json)
  return {err: false}.to_json
end

def validate(mentions)
  processed_mentions = []
  unprocessed_mentions = []
  mentions.each do |mention|
    if !$user_redis.get(mention).nil?
      user_info = JSON.parse($user_redis.get(mention))
      valid_mention = user_info['id'].to_s + '-' + mention.to_s
      processed_mentions << valid_mention
    else
      unprocessed_mentions << mention
    end
  end
  ask_user_service = []
  ask_user_service = JSON.parse(RestClient.post($user_exists,{usernames: unprocessed_mentions.to_json})) if !unprocessed_mentions.empty?
  processed_mentions = processed_mentions + ask_user_service
  processed_mentions
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
  end
  Tweet.collection.insert_many(batch)
end

get '/status' do
  "Number of Tweets: #{Tweet.count}"
end

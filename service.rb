# server.rb
require 'sinatra'
require 'mongoid'
require 'mongoid_search'
require 'byebug'
require 'json'
require 'sinatra/cors'
require_relative 'models/tweet'
require 'redis'

# DB Setup
Mongoid.load! "config/mongoid.yml"

#set binding
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
  $tweet_redis = Redis.new(:host => tweet_uri.host, :port => tweet_uri.port, :password => tweet_uri.password)
  $follow_redis = Redis.new(:host => follow_uri.host, :port => follow_uri.port, :password => follow_uri.password)
  $user_redis = Redis.new(:host => user_uri.host, :port => user_uri.port, :password => user_uri.password)
end

helpers do
  def cache(redis_key, json_tweet)
    $tweet_redis.lpush(redis_key, json_tweet)
    if $tweet_redis.llen(redis_key) > 50
      $tweet_redis.rpop(redis_key)
    end
  end
end

# These are still under construction.

get '/loaderio-3790352c0664df3f597575d62a09d082.txt' do
  send_file 'loaderio-3790352c0664df3f597575d62a09d082.txt'
end
#
post '/api/v1/:apitoken/tweets/new' do
  if !$user_redis.get(params[:apitoken]).nil?
    # byebug
    username = JSON.parse($user_redis.get(params[:apitoken]))["username"]
    user_id = JSON.parse($user_redis.get(params[:apitoken]))["id"]
    mentions = nil
    if !params[:mentions].nil?
      mentions = JSON.parse(params[:mentions])
    end
    result = Hash.new
    tweet = Tweet.new(
      contents: params["tweet-input"],
      date_posted: Time.now,
      user: {username: username,
      id: user_id
    },
      mentions: mentions
    )
    # puts tweet.to_json
    cache("recent", tweet.to_json)
    cache(user_id.to_s + "_feed", tweet.to_json)
    if !$follow_redis.get("#{user_id.to_s} followers").nil?
      JSON.parse($follow_redis.get("#{user_id.to_s} followers")).keys.each do |follower|
        cache(follower, tweet.to_json)
      end
    end
    # send ok message?
    # have rabbitMQ save the Tweet
    # byebug
    saved = tweet.save
    # puts tweet.to_json
    result[:saved] = saved
    return result.to_json
  end
  {err: true}.to_json
end

# ONLY TO BE USED FOR TESTING
delete '/api/v1/tweets/delete' do
  success = Tweet.delete_all
  success.to_json
end

delete '/api/v1/tweets/delete/:user_id' do
  success = Tweet.delete_all(:user_id => params[:user_id])
  success.to_json
end

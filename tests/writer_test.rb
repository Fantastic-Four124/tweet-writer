require 'minitest/autorun'
require 'rack/test'
require 'rake/testtask'
require 'json'
require 'rest-client'
require_relative '../service.rb'
require_relative '../models/tweet.rb'

class WriterTest < Minitest::Test

  include Rack::Test::Methods

  # Setup
  #---------------------------------------------#

  def app
    Sinatra::Application
  end

  @apitoken = "a3432kp97453r5702m345z432q34342f"

  def flush_all
    $tweet_redis.delete("recent")
    $tweet_redis_spare.delete("recent")
    $tweet_redis.delete("175_feed") # userA
    $tweet_redis.delete("180_feed") # userB
    $tweet_redis_spare.delete("175_feed") # userA
    $tweet_redis_spare.delete("180_feed") # userB
    $user_redis.delete(@apitoken)
    $follow_redis.delete("175 followers")
    Tweet.delete_all(contents: "I am a test_tweet")
  end

  def create_apitoken
    $user_redis.set({username: "userA", id: 175}.to_json)
  end

  # Tests
  #--------------------------------------------#

  def unauthorized_tweet_write
    post '/api/v1/:not_a_token/tweets/new', {"tweet-input" => "I am a test tweet"}, "CONTENT_TYPE" => "multipart/form-data"
    assert last_response.body.include?({err: true}.to_json)
  end

  def tweet_write_queue_success
    create_apitoken
    post '/api/v1/#{@apitoken}/tweets/new', {"tweet-input" => "I am a test tweet"}, "CONTENT_TYPE" => "multipart/form-data"
    assert last_response.ok? && last_response.body.include?('ok')
    flush_all
  end

  def tweet_write_queue_fail
    post '/api/v1/#{@apitoken}/tweets/new', {"tweet-input" => nil}, "CONTENT_TYPE" => "multipart/form-data"
    assert last_response.ok? && !last_response.body.include?('ok')
    flush_all
  end

  def cache_tweets
    $follow_redis.set("175 followers", "180") # userB
    post '/api/v1/#{@apitoken}/tweets/new', {"tweet-input" => "I am a test tweet"}, "CONTENT_TYPE" => "multipart/form-data"
    assert JSON.parse($tweet_redis.lpop("recent"))["contents"] == "I am a test tweet"
    assert JSON.parse($tweet_redis_spare.lpop("recent"))["contents"] == "I am a test tweet"
    assert JSON.parse($tweet_redis.lpop("175_feed"))["contents"] == "I am a test tweet"
    assert JSON.parse($tweet_redis_spare.lpop("175_feed"))["contents"] == "I am a test tweet"
    assert JSON.parse($tweet_redis.lpop("180_feed"))["contents"] == "I am a test tweet"
    assert JSON.parse($tweet_redis_spare.lpop("180_feed"))["contents"] == "I am a test tweet"
    flush_all
  end

end

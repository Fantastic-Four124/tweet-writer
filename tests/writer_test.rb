require 'minitest/autorun'
require 'rack/test'
require 'rake/testtask'
require 'json'
require 'rest-client'
require_relative '../service.rb'

class WriterTest < Minitest::Test

  include Rack::Test::Methods

  # Setup
  #---------------------------------------------#

  def app
    Sinatra::Application
  end

  def flush_all
    $tweet_redis.delete("recent")
    $tweet_redis.delete("userA_feed")
    $tweet_redis.delete("userB_feed")
    $follow_redis.delete("userA")
    $follow_redis.delete("userB")
  end

  # Tests
  #--------------------------------------------#

  def unauthorized_tweet_write
  end

  def tweet_write_save_success
  end

  def tweet_write_save_fail
  end

  def cache_tweets
  end

end

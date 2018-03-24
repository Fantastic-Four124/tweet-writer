# server.rb
require 'sinatra'
require 'mongoid'
require 'byebug'
require 'json'
require_relative 'models/tweet'

# DB Setup
Mongoid.load! "mongoid.config"

#set binding
enable :sessions

set :bind, '0.0.0.0' # Needed to work with Vagrant
set :port, 8085

# These are still under construction.

post '/api/v1/tweets/new' do
  result = Hash.new
  tweet = Tweet.new(
    contents: params[:contents],
    user_id: params[:user_id],
    date_posted: Time.now,
    hashtags: JSON.parse(params[:hashtags]),
    mentions: JSON.parse(params[:mentions])
  )
  #byebug
  saved = tweet.save
  #byebug
  result[:saved] = saved
  result.to_json
end

# ONLY TO BE USED FOR TESTING
post '/api/v1/tweets/delete' do
  success = Tweet.where(_id: params[:id]).delete
  byebug
  success.to_json
end

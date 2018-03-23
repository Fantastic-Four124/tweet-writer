# server.rb
require 'sinatra'
require 'mongoid'
require_relative 'models/tweet'

# DB Setup
Mongoid.load! "mongoid.config"

#set binding
enable :sessions

set :bind, '0.0.0.0' # Needed to work with Vagrant
set :port, 8080

# These are still under construction.

post '/api/v1/tweets/new' do
  result = Hash.new
  tweet = Tweet.new(
    contents: params[:tweet],
    user_id: session[:user_id],
    date_posted: Time.now,
    hashtags: JSON.parse(params[:hashtags]),
    mentions: JSON.parse(params[:mentions])
  )
  saved = tweet.save
  byebug
  result[:saved] = saved
  result.to_json
end

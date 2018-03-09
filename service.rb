# server.rb
require 'sinatra'
require 'mongoid'
require_relative 'models/tweet'

# DB Setup
Mongoid.load! "mongoid.config"

#set binding
enable :sessions

set :bind, '0.0.0.0' # Needed to work with Vagrant

# These are still under construction.

post '/api/v1/tweets/new' do
  # tweet = Tweet.new(
  #   contents: params[:tweet],
  #   user_id: session[:user_id],
  #   date_posted: Time.now,
  #   hashtags: params[:hashtags],
  #   mentions: params[:mentions]
  # )
  # tweet.save!
  #redirect '/api/v1/{route}'
end

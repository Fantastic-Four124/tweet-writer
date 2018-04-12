# server.rb
require 'sinatra'
require 'mongoid'
require 'mongoid_search'
require 'byebug'
require 'json'
require 'sinatra/cors'
require_relative 'models/tweet'

# DB Setup
Mongoid.load! "config/mongoid.yml"

#set binding
enable :sessions

set :bind, '0.0.0.0' # Needed to work with Vagrant
set :port, 8085

set :allow_origin, '\*'
set :allow_methods, 'GET,HEAD,POST'
set :allow_headers, 'accept,content-type,if-modified-since'
set :expose_headers, 'location,link'

# These are still under construction.

get '/loaderio-3790352c0664df3f597575d62a09d082.txt' do
  send_file 'loaderio-3790352c0664df3f597575d62a09d082.txt'
end

post '/api/v1/tweets/new' do
  result = Hash.new
  tweet = Tweet.new(
    contents: params[:contents],
    username: params[:username],
    user_id: params[:user_id],
    date_posted: Time.now,
    hashtags: JSON.parse(params[:hashtags]),
    mentions: JSON.parse(params[:mentions])
  )
  saved = tweet.save
  result[:saved] = saved
  result.to_json
end

# ONLY TO BE USED FOR TESTING
# post '/api/v1/tweets/delete' do
#   success = Tweet.where(_id: params[:id]).delete
#   byebug
#   success.to_json
# end

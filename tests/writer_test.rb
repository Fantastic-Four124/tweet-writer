require 'minitest/autorun'
require 'rack/test'
require 'rake/testtask'
require 'json'
require 'rest-client'
require_relative '../service.rb'

class WriterTest < Minitest::Test

  include Rack::Test::Methods

  def app
    Sinatra::Application
  end
  
end

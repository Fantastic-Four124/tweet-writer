#!/usr/bin/env ruby
require 'bunny'
require 'thread'
require 'mongoid'
require 'mongoid_search'
require 'sinatra'
require 'sinatra/activerecord'
require 'byebug'
#require_relative 'test_interface.rb'
require 'time_difference'
require 'time'
require 'json'
#require 'rest-client'
require 'redis'
require_relative 'models/tweet'

#Dir[File.dirname(__FILE__) + '/api/v1/user_service/*.rb'].each { |file| require file }

class WriterServer
  def initialize(id)
    @connection = Bunny.new(id)
    @connection.start
    @channel = @connection.create_channel
  end

  def start(queue_name)
    @queue = channel.queue(queue_name)
    @exchange = channel.default_exchange
    subscribe_to_queue
  end

  def stop
    channel.close
    connection.close
  end

  private

  attr_reader :channel, :exchange, :queue, :connection, :exchange2, :queue2

  def subscribe_to_queue
    queue.subscribe(block: true) do |_delivery_info, properties, payload|
      puts "[x] Get message #{payload}. Gonna do some user service about #{payload}"
      result = process(payload)
      puts result
      #byebug
      exchange.publish(
        result,
        routing_key: properties.reply_to,
        correlation_id: properties.correlation_id
      )
    end
  end

  def process(original)
    hydrate_original = JSON.parse(original)
    tweet = Tweet.new(
      contents: hydrate_original["contents"],
      date_posted: hydrate_original["date_posted"],
      user: {username: hydrate_original["user"]["username"],
      id: hydrate_original["user"]["user_id"]
    },
      mentions: hydrate_original["mentions"]
    )
    tweet.save
  end

end


begin
  server = WriterServer.new(ENV["RABBITMQ_BIGWIG_RX_URL"])

  puts ' [x] Awaiting RPC requests'
  server.start('writer_queue')
  #server.start2('rpc_queue_hello')
rescue Interrupt => _
  server.stop
end

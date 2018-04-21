require 'mongoid'
require 'mongoid_search'
require_relative '../models/tweet'

Mongoid.load! "../config/mongoid.yml"

def main
  batch = []
  10.times do |i|
    batch << {
      contents: "test tweet!",
      date_posted: Time.now,
      user: {username: "user#{i}",
      id: i
    },
      mentions: []
    }
  end
  puts batch
  saved = Tweet.collection.insert_many(batch)
  puts "Saved? #{saved}"
end

main

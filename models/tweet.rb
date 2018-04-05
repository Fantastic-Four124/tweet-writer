class Tweet
  include Mongoid::Document
  include Mongoid::Timestamps
  include Mongoid::Search

  field :contents, type: String
  field :date_posted, type: DateTime
  field :username, type: String
  field :user_id, type: String
  field :hashtags, type: Array
  field :mentions, type: Array

  attr_readonly :username, :user_id, :date_posted, :contents
  validates :username, :user_id, presence: true
  search_in :contents, :hashtags
  store_in collection: 'nt-tweets'
end

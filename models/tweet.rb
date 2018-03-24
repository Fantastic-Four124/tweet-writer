class Tweet
  include Mongoid::Document
  include Mongoid::Timestamps

  field :contents, type: String
  field :date_posted, type: DateTime
  field :user_id, type: String
  field :hashtags, type: Array
  field :mentions, type: Array

  attr_readonly :user_id, :date_posted, :contents
  validates :user_id, presence: true
  store_in collection: 'nt-tweets'
end

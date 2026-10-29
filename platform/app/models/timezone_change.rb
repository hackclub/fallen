# frozen_string_literal: true

# A change to someone's timezone, or one refused for coming within User::TIMEZONE_CHANGE_EVERY of the last
# (User#change_timezone). `source` is where the new zone came from: the browser.
# == Schema Information
#
# Table name: timezone_changes
#
#  id         :bigint           not null, primary key
#  from       :string           not null
#  refused    :boolean          default(FALSE), not null
#  source     :string           not null
#  to         :string           not null
#  created_at :datetime         not null
#  user_id    :bigint           not null
#
# Indexes
#
#  index_timezone_changes_on_user_id_and_created_at  (user_id,created_at)
#
# Foreign Keys
#
#  fk_rails_...  (user_id => users.id)
#
class TimezoneChange < ApplicationRecord
  has_paper_trail

  SOURCES = %w[browser].freeze

  belongs_to :user

  validates :from, :to, presence: true
  validates :source, inclusion: { in: SOURCES }
end

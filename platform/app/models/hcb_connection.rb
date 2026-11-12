# The one HCB organization token, connected by an admin (HcbAuthController) and refreshed by HcbTokenRefreshJob.
# == Schema Information
#
# Table name: hcb_connections
#
#  id                :bigint           not null, primary key
#  access_token      :text
#  ledger_checked_at :datetime
#  ledger_error      :text
#  refresh_token     :text
#  token_expires_at  :datetime
#  created_at        :datetime         not null
#  updated_at        :datetime         not null
#  connected_by_id   :bigint           not null
#
# Indexes
#
#  index_hcb_connections_on_connected_by_id  (connected_by_id)
#
# Foreign Keys
#
#  fk_rails_...  (connected_by_id => users.id)
#
class HcbConnection < ApplicationRecord
  encrypts :access_token, :refresh_token
  has_paper_trail skip: %i[access_token refresh_token]

  belongs_to :connected_by, class_name: "User"

  def self.current = order(:id).last

  def self.connect!(token, by:)
    transaction do
      delete_all
      create!(connected_by: by, access_token: token[:access_token], refresh_token: token[:refresh_token],
        token_expires_at: token[:expires_in].to_i.seconds.from_now)
    end
  end

  def usable_token = access_token.presence && token_expires_at&.future? ? access_token : nil
  def connected? = usable_token.present?
  def expiring_soon? = token_expires_at.present? && token_expires_at < 30.minutes.from_now

  def refresh!
    with_lock do
      next unless expiring_soon? && refresh_token.present?

      token = Hcb.refresh(refresh_token)
      update!(access_token: token[:access_token], refresh_token: token[:refresh_token] || refresh_token,
        token_expires_at: token[:expires_in].to_i.seconds.from_now)
    end
  rescue Faraday::UnauthorizedError, Faraday::BadRequestError
    update!(access_token: nil, refresh_token: nil, token_expires_at: nil)
    raise
  end
end

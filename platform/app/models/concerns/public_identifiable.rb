# frozen_string_literal: true

# Stripe-like public IDs (usr_Ab12Cd) with no extra column. From 24c02/thirdrail (originally @msw).
#
#   class User < ApplicationRecord
#     include PublicIdentifiable
#     set_public_id_prefix :usr
#   end
#
#   user.public_id            # => "usr_Ab12Cd"
#   User.find_by_public_id!("usr_Ab12Cd")
module PublicIdentifiable
  SEPARATOR = "_"

  extend ActiveSupport::Concern

  included do
    include Hashid::Rails
    class_attribute :public_id_prefix
  end

  def public_id = "#{self.class.get_public_id_prefix}#{SEPARATOR}#{hashid}"

  def to_param = public_id

  class_methods do
    def set_public_id_prefix(prefix)
      self.public_id_prefix = prefix.to_s.downcase
    end

    def find_by_public_id(id)
      return nil unless id.is_a?(String)

      prefix, _, hash = id.rpartition(SEPARATOR)
      return nil unless prefix.downcase == get_public_id_prefix

      find_by_hashid(hash)
    end

    def find_by_public_id!(id)
      find_by_public_id(id) || raise(ActiveRecord::RecordNotFound.new("Couldn't find #{name} with public id #{id.inspect}", name))
    end

    def get_public_id_prefix
      return public_id_prefix.to_s.downcase if public_id_prefix.present?

      raise NotImplementedError, "#{name} includes PublicIdentifiable but never called set_public_id_prefix"
    end
  end
end

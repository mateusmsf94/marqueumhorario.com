# frozen_string_literal: true

# MembershipManagement concern for models that have user memberships.
# Handles adding/removing managers and checking membership status.
#
# Extracted from Office model to separate membership concerns.
module MembershipManagement
  extend ActiveSupport::Concern

  # Check if a user manages this office
  #
  # @param user [User] The user to check
  # @return [Boolean] true if user manages this office
  def managed_by?(user)
    return false unless user

    users.exists?(user.id)
  end

  # Add a user as manager of this office
  # Creates an office_membership record if one doesn't exist
  #
  # @param user [User] The user to add as manager
  # @return [Boolean] true if successfully added or already exists
  def add_manager(user)
    return false unless user
    return true if managed_by?(user)

    users << user
    true
  rescue ActiveRecord::RecordInvalid
    false
  end

  # Remove a user from managing this office
  # Deletes the office_membership record
  #
  # @param user [User] The user to remove
  # @return [User, nil] The removed user or nil
  def remove_manager(user)
    users.delete(user)
  end

  # Get all active managers for this office
  # Returns users with active office_membership records
  #
  # @return [ActiveRecord::Relation<User>] Active managers
  def active_managers
    users.where(office_memberships: { is_active: true })
  end
end

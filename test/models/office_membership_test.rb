require "test_helper"

class OfficeMembershipTest < ActiveSupport::TestCase
  test "should not save without user" do
    membership = OfficeMembership.new(office: offices(:main_office))
    assert_not membership.save
    assert_includes membership.errors[:user], "must exist"
  end

  test "should not save without office" do
    membership = OfficeMembership.new(user: users(:provider_john))
    assert_not membership.save
    assert_includes membership.errors[:office], "must exist"
  end

  test "should not allow duplicate membership" do
    membership1 = office_memberships(:john_main_office)
    membership2 = OfficeMembership.new(
      user: membership1.user,
      office: membership1.office
    )
    assert_not membership2.save
    assert_includes membership2.errors[:user_id], "is already a member of this office"
  end

  test "should allow user to be office member" do
    provider = users(:provider_jane)
    office = offices(:west_coast_office)
    membership = OfficeMembership.create!(user: provider, office: office)
    assert membership.persisted?
  end

  test "should have default role of member" do
    membership = OfficeMembership.new(
      user: users(:provider_jane),
      office: offices(:west_coast_office)
    )
    assert_equal "member", membership.role
  end

  test "should default is_active to true" do
    membership = OfficeMembership.create!(
      user: users(:provider_jane),
      office: offices(:west_coast_office)
    )
    assert membership.is_active
  end

  # Scopes
  test "active scope should return only active memberships" do
    active_memberships = OfficeMembership.active
    assert active_memberships.all?(&:is_active)
  end

  test "for_user scope should filter by user" do
    user = users(:provider_john)
    memberships = OfficeMembership.for_user(user)
    assert memberships.all? { |m| m.user_id == user.id }
  end

  test "for_office scope should filter by office" do
    office = offices(:main_office)
    memberships = OfficeMembership.for_office(office)
    assert memberships.all? { |m| m.office_id == office.id }
  end

  # Instance methods
  test "activate! should set is_active to true" do
    membership = office_memberships(:john_main_office)
    membership.update!(is_active: false)
    membership.activate!
    assert membership.is_active
  end

  test "deactivate! should set is_active to false" do
    membership = office_memberships(:john_main_office)
    membership.deactivate!
    assert_not membership.is_active
  end
end

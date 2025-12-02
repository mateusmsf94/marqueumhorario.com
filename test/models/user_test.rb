require "test_helper"

class UserTest < ActiveSupport::TestCase
  def valid_provider_attributes
    {
      first_name: "Test",
      last_name: "Provider",
      email: "provider@test.com",
      password: "password123",
      password_confirmation: "password123"
    }
  end

  def valid_customer_attributes
    {
      first_name: "Test",
      last_name: "Customer",
      email: "customer@test.com",
      password: "password123",
      password_confirmation: "password123"
    }
  end

  # Presence validations
  test "should not save without first_name" do
    user = User.new(valid_customer_attributes.except(:first_name))
    assert_not user.save
    assert_includes user.errors[:first_name], "can't be blank"
  end

  test "should not save without last_name" do
    user = User.new(valid_customer_attributes.except(:last_name))
    assert_not user.save
    assert_includes user.errors[:last_name], "can't be blank"
  end

  test "should not save without email" do
    user = User.new(valid_customer_attributes.except(:email))
    assert_not user.save
    assert_includes user.errors[:email], "can't be blank"
  end

  # Length validations
  test "should not save with first_name longer than 100 characters" do
    user = User.new(valid_customer_attributes.merge(first_name: "a" * 101))
    assert_not user.save
    assert_includes user.errors[:first_name], "is too long (maximum is 100 characters)"
  end

  test "should not save with phone longer than 20 characters" do
    user = User.new(valid_customer_attributes.merge(phone: "1" * 21))
    assert_not user.save
    assert_includes user.errors[:phone], "is too long (maximum is 20 characters)"
  end

  # Email validations
  test "should not save with duplicate email" do
    user1 = User.create!(valid_customer_attributes)
    user2 = User.new(valid_customer_attributes.merge(email: user1.email.upcase))
    assert_not user2.save
    assert_includes user2.errors[:email], "has already been taken"
  end

  # CPF validations
  test "should accept valid 11-digit CPF" do
    user = User.new(valid_customer_attributes.merge(cpf: "12345678902"))
    assert user.valid?
  end

  test "should reject CPF shorter than 11 digits" do
    user = User.new(valid_customer_attributes.merge(cpf: "123456789"))
    assert_not user.valid?
    assert_includes user.errors[:cpf], "is the wrong length (should be 11 characters)"
  end

  test "should reject CPF with all same digits" do
    user = User.new(valid_customer_attributes.merge(cpf: "11111111111"))
    assert_not user.valid?
    assert_includes user.errors[:cpf], "is invalid"
  end

  test "should allow blank CPF" do
    user = User.new(valid_customer_attributes.merge(cpf: nil))
    assert user.valid?
  end

  test "should enforce unique CPF" do
    user1 = User.create!(valid_customer_attributes.merge(cpf: "55566677788"))
    user2 = User.new(valid_provider_attributes.merge(cpf: "55566677788"))
    assert_not user2.save
    assert_includes user2.errors[:cpf], "has already been taken"
  end

  # Instance methods
  test "full_name should combine first and last name" do
    user = users(:customer_alice)
    assert_equal "Alice Johnson", user.full_name
  end

  test "manages_office? should return true for provider managing office" do
    provider = users(:provider_john)
    office = offices(:main_office)
    assert provider.manages_office?(office)
  end

  test "manages_office? should return false for non-member" do
    non_member = users(:customer_alice)
    office = offices(:main_office)
    assert_not non_member.manages_office?(office)
  end

  # Password validations (from Devise)
  test "should require password on create" do
    user = User.new(valid_customer_attributes.except(:password))
    assert_not user.save
    assert_includes user.errors[:password], "can't be blank"
  end

  test "should require password confirmation match" do
    user = User.new(valid_customer_attributes.merge(password_confirmation: "different"))
    assert_not user.valid?
    assert_includes user.errors[:password_confirmation], "doesn't match Password"
  end
end

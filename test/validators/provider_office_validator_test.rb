require "test_helper"

class ProviderOfficeValidatorTest < ActiveSupport::TestCase
  class TestRecord
    include ActiveModel::Validations

    attr_accessor :provider, :office

    validates_with ProviderOfficeValidator
  end

  class CustomAttributeRecord
    include ActiveModel::Validations

    attr_accessor :provider_user, :assigned_office

    validates_with ProviderOfficeValidator, provider: :provider_user, office: :assigned_office
  end

  test "valid when provider manages the office" do
    record = TestRecord.new
    record.provider = users(:provider_john)
    record.office = offices(:main_office)

    assert record.valid?
    assert_empty record.errors[:provider]
  end

  test "invalid when provider does not manage the office" do
    record = TestRecord.new
    record.provider = users(:provider_jane)
    record.office = offices(:west_coast_office)

    assert_not record.valid?
    assert_includes record.errors[:provider], "must work at this office"
  end

  test "supports custom association names" do
    record = CustomAttributeRecord.new
    record.provider_user = users(:provider_john)
    record.assigned_office = offices(:main_office)

    assert record.valid?
  end
end

class ProviderOfficeValidator < ActiveModel::Validator
  def validate(record)
    provider_attr = options[:provider] || :provider
    office_attr = options[:office] || :office

    return unless record.respond_to?(provider_attr) && record.respond_to?(office_attr)

    provider = record.send(provider_attr)
    office = record.send(office_attr)

    return if provider.nil? || office.nil?
    return if office.managed_by?(provider)

    record.errors.add(provider_attr, "must work at this office")
  end
end

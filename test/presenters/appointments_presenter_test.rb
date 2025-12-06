require "test_helper"

class AppointmentsPresenterTest < ActiveSupport::TestCase
  setup do
    @appointments = [
      appointments(:pending_appointment),
      appointments(:confirmed_appointment)
    ]

    @presenter = AppointmentsPresenter.new(@appointments)
  end

  test "initializes with appointments" do
    assert_equal @appointments, @presenter.appointments
  end

  test "groups appointments by date" do
    grouped = @presenter.grouped_by_date

    assert_instance_of Hash, grouped
    assert grouped.keys.all? { |key| key.is_a?(Date) }
  end

  test "counts total appointments" do
    assert_equal @appointments.count, @presenter.total_count
  end

  test "handles empty appointments" do
    empty_presenter = AppointmentsPresenter.new([])

    assert_equal 0, empty_presenter.total_count
    assert_equal({}, empty_presenter.grouped_by_date)
  end
end

class WorkPeriodValidator
  def initialize(work_periods, appointment_duration, buffer_minutes)
    @work_periods = work_periods
    @appointment_duration = appointment_duration
    @buffer_minutes = buffer_minutes
    @errors = []
  end

  private
end

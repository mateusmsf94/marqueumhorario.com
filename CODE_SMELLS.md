# Code Smells Analysis Report

**Project**: Marque Um Horário - Appointment Scheduling System
**Generated**: December 5, 2025
**Rails Version**: 8.1.1
**Total Issues**: 20 (4 High | 7 Medium | 9 Low)

---

## Table of Contents

1. [Executive Summary](#executive-summary)
2. [How to Use This Document](#how-to-use-this-document)
3. [High Priority Issues](#high-priority-issues)
   - [H1: Potential N+1 Query Issues in MembershipManagement](#h1-potential-n1-query-issues-in-membershipmanagement)
   - [H2: Complex Validation Logic in WorkSchedule](#h2-complex-validation-logic-in-workschedule)
   - [H3: Inefficient Time Duration Calculation in AvailabilityService](#h3-inefficient-time-duration-calculation-in-availabilityservice)
   - [H4: Database Query in Appointment before_save Callback](#h4-database-query-in-appointment-before_save-callback)
4. [Medium Priority Issues](#medium-priority-issues)
   - [M1: Fat Model - WorkScheduleCollection](#m1-fat-model---workschedulecollection)
   - [M2: Missing Database Indexes](#m2-missing-database-indexes)
   - [M3: Magic Numbers in Validations](#m3-magic-numbers-in-validations)
   - [M4: Unclear Method Naming in WorkSchedule](#m4-unclear-method-naming-in-workschedule)
   - [M5: Duplicate Code Pattern - activate!/deactivate!](#m5-duplicate-code-pattern---activatedeactivate)
   - [M6: Inconsistent Hash Key Access](#m6-inconsistent-hash-key-access)
   - [M7: Missing Scopes for Common Queries](#m7-missing-scopes-for-common-queries)
5. [Low Priority Issues](#low-priority-issues)
   - [L1: Boolean Trap in GeocodeOfficeService](#l1-boolean-trap-in-geocodeofficeservice)
   - [L2: Inconsistent Default Duration Constants](#l2-inconsistent-default-duration-constants)
   - [L3: Complex Conditional in AvailabilityCalendar](#l3-complex-conditional-in-availabilitycalendar)
   - [L4: Typo in Comment](#l4-typo-in-comment)
   - [L5: Unused Private Method](#l5-unused-private-method)
   - [L6: Missing Tests for Services and Concerns](#l6-missing-tests-for-services-and-concerns)
   - [L7: Hard-coded Pagination Limits](#l7-hard-coded-pagination-limits)
   - [L8: Missing Eager Loading in Controllers](#l8-missing-eager-loading-in-controllers)
   - [L9: Duplicate Role Checking Pattern](#l9-duplicate-role-checking-pattern)
6. [Prevention Patterns](#prevention-patterns)
7. [References](#references)

---

## Executive Summary

### Health Metrics

| Metric | Count | Status |
|--------|-------|--------|
| High Priority Issues | 4 | 🔴 Needs Attention |
| Medium Priority Issues | 7 | 🟡 Plan for Refactoring |
| Low Priority Issues | 9 | 🟢 Address Opportunistically |
| Total Active Issues | 20 | 📊 Manageable |
| Quick Wins (< 2 hours) | 6 | ✨ Easy Improvements |

### Quick Impact Assessment

**What's Working Well:**
- ✅ Strong service layer with single responsibility (AvailabilityService, SlotGenerator, etc.)
- ✅ Value objects for data encapsulation (TimePeriod, SlotConfiguration)
- ✅ Comprehensive use of concerns (TemporalScopes, TimeParsing, Geocodable)
- ✅ Consistent use of scopes for common queries
- ✅ Recent refactoring success (WorkScheduleCollection decomposition)

**What Needs Attention:**
1. 🔴 Performance: N+1 query potential and inefficient calculations
2. 🔴 Complexity: Database queries in callbacks affecting performance
3. 🟡 Maintainability: Magic numbers and duplicate patterns
4. 🟡 Testing: Missing test coverage for 3 services and 1 concern

**Quick Wins Available:**
- L4: Fix typo in comment (5 minutes)
- L5: Remove unused private method (10 minutes)
- L2: Consolidate duplicate constants (30 minutes)
- L7: Extract hard-coded limits to constants (1 hour)
- L9: Add `provider?` helper method (1 hour)
- M3: Extract magic numbers to named constants (1.5 hours)

**Total Quick Win Effort:** ~4 hours for 6 improvements

---

## How to Use This Document

### For Developers

**Prioritization Guide:**
- 🔴 **High Priority**: Address before new features or when working in related areas. These impact performance or add significant complexity.
- 🟡 **Medium Priority**: Address during related work or dedicated refactoring sprints. These improve maintainability.
- 🟢 **Low Priority**: Address during cleanup sprints or as learning exercises. These polish code quality.

**Effort Indicators:**
- ⏱️ **Quick** (< 2 hours): Can be done in a single sitting, minimal risk
- ⏱️⏱️ **Medium** (2-8 hours): Requires careful planning, moderate testing
- ⏱️⏱️⏱️ **Large** (8+ hours): Significant refactoring, comprehensive testing needed

**Implementation Strategy:**
1. Start with Quick Wins to build momentum
2. Tackle High Priority issues before major feature work
3. Address Medium Priority issues during related refactoring
4. Schedule dedicated time for Low Priority issues periodically

### For Code Reviewers

**Use this document to:**
- Check PRs against documented patterns
- Prevent introduction of similar code smells
- Suggest refactoring opportunities when related code is modified
- Ensure new code follows Prevention Patterns (see section below)

**Red Flags in Code Review:**
- ❌ New callbacks that query the database
- ❌ Hard-coded magic numbers instead of named constants
- ❌ Missing eager loading on associations
- ❌ Duplicate code that could be extracted to concerns
- ❌ Business logic in controllers

---

## High Priority Issues

### H1: Potential N+1 Query Issues in MembershipManagement

**Category**: Performance
**Effort**: ⏱️⏱️ Medium (~4 hours)
**Impact**: Performance degradation at scale - each office iteration triggers additional queries

**Description**:
The `MembershipManagement` concern includes methods like `managed_by?` and `active_managers` that execute database queries. When these methods are called within loops (e.g., iterating over offices), they create N+1 query problems that can significantly degrade performance as the dataset grows.

**Evidence**:
```ruby
# File: app/models/concerns/membership_management.rb:17
def managed_by?(user)
  return false unless user
  users.exists?(user.id)  # ⚠️ Executes query each time
end

# File: app/models/concerns/membership_management.rb:49
def active_managers
  users.where(office_memberships: { is_active: true })  # ⚠️ Not optimized for eager loading
end
```

**Problem Analysis**:
- `managed_by?` calls `users.exists?` which executes a query every time it's called
- When iterating over offices (e.g., `@offices.each { |office| office.managed_by?(user) }`), this creates N+1 queries
- `active_managers` requires a join but doesn't leverage eager loading efficiently
- No documentation warning developers about N+1 potential

**Real-World Impact**:
```ruby
# Controller code that triggers N+1:
@offices = current_user.offices  # 1 query
@offices.each do |office|
  if office.managed_by?(some_user)  # N additional queries!
    # ...
  end
end
```

**Proposed Solution**:

**Option 1: Add Documentation** (Quickest - 1 hour)
```ruby
# File: app/models/concerns/membership_management.rb
module MembershipManagement
  extend ActiveSupport::Concern

  # ⚠️ N+1 WARNING: When checking management for multiple offices,
  # use eager loading: Office.includes(:users).where(...)
  # Or load all managed offices at once: current_user.offices
  def managed_by?(user)
    return false unless user
    users.exists?(user.id)
  end
end
```

**Option 2: Add Scope-Based Alternative** (Better - 3 hours)
```ruby
# File: app/models/office.rb
scope :managed_by_user, ->(user) {
  joins(:office_memberships)
    .where(office_memberships: { user_id: user.id, is_active: true })
}

# Usage in controllers:
@offices = Office.managed_by_user(current_user)  # Single query
```

**Implementation Steps**:
1. **Add documentation warnings** - 30 minutes
   - Document N+1 risk in MembershipManagement concern
   - Add usage examples showing proper eager loading

2. **Create scope-based alternatives** - 2 hours
   - Add `Office.managed_by_user(user)` scope
   - Add `User.managing_offices` scope
   - Update controllers to use scopes instead of iteration

3. **Update controllers** - 1 hour
   - Replace `.each { |office| office.managed_by?(user) }` patterns
   - Add `.includes(:users)` where managed_by? must be used
   - Verify with Bullet gem or query logging

4. **Add tests** - 30 minutes
   - Test new scopes return correct results
   - Add performance test verifying query count

**Better Code Example**:
```ruby
# BEFORE (N+1 problem):
@offices = Office.all
@offices.each do |office|
  @can_manage = office.managed_by?(current_user)
end

# AFTER (single query):
@offices = Office.managed_by_user(current_user)
# or if you need all offices with eager loading:
@offices = Office.includes(:users)
```

**Affected Files**:
- `app/models/concerns/membership_management.rb` - Add documentation/scopes
- `app/controllers/providers/dashboard_controller.rb` - Use eager loading
- `app/controllers/providers/offices_controller.rb` - Use scopes
- `test/models/concerns/membership_management_test.rb` - **CREATE THIS FILE** with scope tests

**Dependencies**:
- Blocks: None
- Blocked by: None

**References**:
- [Bullet gem for N+1 detection](https://github.com/flyerhzm/bullet)
- [Rails Guide: Active Record Query Interface](https://guides.rubyonrails.org/active_record_querying.html#eager-loading-associations)

---

### H2: Complex Validation Logic in WorkSchedule

**Category**: Maintainability / Code Duplication
**Effort**: ⏱️⏱️ Medium (~3 hours)
**Impact**: Duplicates time conversion logic that already exists in TimeParsing module

**Description**:
The `work_day_must_accommodate_at_least_one_slot` validation in WorkSchedule manually converts times to minutes for comparison. This logic duplicates functionality already available in the `TimeParsing` module (which the model includes), violating DRY principles and increasing maintenance burden.

**Evidence**:
```ruby
# File: app/models/work_schedule.rb:123-135
def work_day_must_accommodate_at_least_one_slot
  return unless opening_time && closing_time && slot_duration_minutes

  # Convert times to minutes for comparison
  opening_minutes = opening_time.hour * 60 + opening_time.min
  closing_minutes = closing_time.hour * 60 + closing_time.min
  available_minutes = closing_minutes - opening_minutes

  if available_minutes < slot_duration_minutes
    errors.add(:slot_duration_minutes,
               "is too long for the available work hours (#{available_minutes} minutes available)")
  end
end
```

**Problem Analysis**:
- Manual time-to-minutes conversion: `opening_time.hour * 60 + opening_time.min`
- WorkSchedule already includes `TimeParsing` concern (line 5)
- `TimeParsing` has methods like `parse_time` and time manipulation utilities
- Duplicating this logic makes it harder to maintain time-handling consistency
- If time conversion logic needs to change, it must be updated in multiple places

**Proposed Solution**:

Extract time conversion to use `TimeParsing` module methods or create a new helper method within TimeParsing.

**Implementation Steps**:
1. **Review TimeParsing concern** - 30 minutes
   - Check existing methods in `app/models/concerns/time_parsing.rb`
   - Determine if a `time_to_minutes` helper exists or should be added

2. **Add time_to_minutes helper to TimeParsing** - 1 hour
   ```ruby
   # File: app/models/concerns/time_parsing.rb
   module TimeParsing
     # ... existing code ...

     # Convert a Time object to total minutes since midnight
     # @param time [Time, nil] The time to convert
     # @return [Integer, nil] Total minutes or nil if time is nil
     def time_to_minutes(time)
       return nil unless time
       time.hour * 60 + time.min
     end

     # Calculate minutes between two times
     # @param start_time [Time] Start time
     # @param end_time [Time] End time
     # @return [Integer] Minutes between times
     def minutes_between(start_time, end_time)
       time_to_minutes(end_time) - time_to_minutes(start_time)
     end
   end
   ```

3. **Refactor WorkSchedule validation** - 30 minutes
   ```ruby
   # File: app/models/work_schedule.rb
   def work_day_must_accommodate_at_least_one_slot
     return unless opening_time && closing_time && slot_duration_minutes

     available_minutes = minutes_between(opening_time, closing_time)

     if available_minutes < slot_duration_minutes
       errors.add(:slot_duration_minutes,
                  "is too long for the available work hours (#{available_minutes} minutes available)")
     end
   end
   ```

4. **Update tests** - 1 hour
   - Add tests for new TimeParsing helper methods
   - Verify WorkSchedule validation still works correctly
   - Test edge cases (midnight crossing, invalid times)

**Better Code Example**:
```ruby
# BEFORE (manual conversion):
def work_day_must_accommodate_at_least_one_slot
  return unless opening_time && closing_time && slot_duration_minutes

  opening_minutes = opening_time.hour * 60 + opening_time.min
  closing_minutes = closing_time.hour * 60 + closing_time.min
  available_minutes = closing_minutes - opening_minutes
  # ...
end

# AFTER (using concern):
def work_day_must_accommodate_at_least_one_slot
  return unless opening_time && closing_time && slot_duration_minutes

  available_minutes = minutes_between(opening_time, closing_time)
  # ...
end
```

**Affected Files**:
- `app/models/concerns/time_parsing.rb` - Add helper methods
- `app/models/work_schedule.rb` - Refactor validation to use helpers
- `test/models/concerns/time_parsing_test.rb` - Add tests for new helpers
- `test/models/work_schedule_test.rb` - Verify validation still works

**Dependencies**:
- Blocks: None
- Blocked by: None

**References**:
- [Rails Concerns Guide](https://api.rubyonrails.org/classes/ActiveSupport/Concern.html)
- [Refactoring: Extracting Methods](https://refactoring.com/catalog/extractMethod.html)

---

### H3: Inefficient Time Duration Calculation in AvailabilityService

**Category**: Performance / Code Quality
**Effort**: ⏱️ Quick (~1 hour)
**Impact**: Verbose code with manual calculations when simpler alternatives exist

**Description**:
The `total_available_minutes` method in AvailabilityService manually iterates through periods, converts times, and sums durations. This is inefficient and verbose when the `TimePeriod` value object already provides a `duration` method that returns seconds.

**Evidence**:
```ruby
# File: app/services/availability_service.rb:54-68
def total_available_minutes
  total = 0
  available_periods.each do |period|
    next unless period.start_time && period.end_time

    # Convert to time objects and calculate difference in seconds
    start_time = period.start_time.to_time
    end_time = period.end_time.to_time
    seconds = end_time.to_f - start_time.to_f
    minutes = (seconds / 60).to_i
    total += minutes
  end
  total
end
```

**Problem Analysis**:
- Verbose iteration with accumulator pattern when Ruby's `sum` is more idiomatic
- Manual time arithmetic (`end_time.to_f - start_time.to_f`)
- Variable name collision: `start_time` and `end_time` are both method parameters and local variables
- TimePeriod already has `duration` method (returns duration in seconds)
- Converting seconds to minutes manually with magic number `60`

**Proposed Solution**:

Simplify to use `sum` with TimePeriod's `duration` method.

**Implementation Steps**:
1. **Verify TimePeriod has duration method** - 10 minutes
   - Check `app/values/time_period.rb` for `duration` method
   - Confirm it returns seconds (based on standard Ruby Time behavior)

2. **Refactor to use sum** - 20 minutes
   ```ruby
   # File: app/services/availability_service.rb
   def total_available_minutes
     available_periods
       .compact # Remove nil periods
       .sum { |period| (period.duration / 60).to_i }
   end
   ```

3. **Alternative: Extract constant for magic number** - 10 minutes
   ```ruby
   # At top of file or in a constants module
   SECONDS_PER_MINUTE = 60

   def total_available_minutes
     available_periods
       .compact
       .sum { |period| (period.duration / SECONDS_PER_MINUTE).to_i }
   end
   ```

4. **Update tests** - 20 minutes
   - Verify existing tests still pass
   - Add edge case test for empty periods
   - Add test for nil period handling

**Better Code Example**:
```ruby
# BEFORE (15 lines, verbose):
def total_available_minutes
  total = 0
  available_periods.each do |period|
    next unless period.start_time && period.end_time
    start_time = period.start_time.to_time
    end_time = period.end_time.to_time
    seconds = end_time.to_f - start_time.to_f
    minutes = (seconds / 60).to_i
    total += minutes
  end
  total
end

# AFTER (3 lines, clear intent):
SECONDS_PER_MINUTE = 60

def total_available_minutes
  available_periods.sum { |period| (period.duration / SECONDS_PER_MINUTE).to_i }
end
```

**Affected Files**:
- `app/services/availability_service.rb` - Refactor `total_available_minutes` method
- `test/services/availability_service_test.rb` - Verify tests pass

**Dependencies**:
- Blocks: None
- Blocked by: None
- Related: H2 (both involve time calculation simplification)

**References**:
- [Ruby Enumerable#sum](https://ruby-doc.org/core-3.1.0/Enumerable.html#method-i-sum)
- [TimePeriod value object documentation](./app/values/time_period.rb)

---

### H4: Database Query in Appointment before_save Callback

**Category**: Performance / Testing
**Effort**: ⏱️⏱️⏱️ Large (~6 hours)
**Impact**: Executes database query on every save, making tests slower and complicating logic

**Description**:
The Appointment model has a `before_save` callback that queries the database to find the provider's work schedule and set the appointment duration. This runs on every save (not just create), executes a potentially slow query, and makes the model harder to test because callbacks always fire.

**Evidence**:
```ruby
# File: app/models/appointment.rb:32
before_save :set_duration_from_work_schedule

def set_duration_from_work_schedule
  return unless provider && office && scheduled_at

  work_schedule = WorkSchedule
    .active
    .for_provider(provider_id)
    .for_office(office_id)
    .for_day(scheduled_at.wday)
    .first

  if work_schedule
    total_minutes = work_schedule.slot_duration_minutes + work_schedule.slot_buffer_minutes
    self.duration_minutes = total_minutes
  else
    self.duration_minutes = DEFAULT_DURATION_MINUTES
  end
end
```

**Problem Analysis**:
- Database query executes on **every save**, not just when duration should change
- Callback runs even when updating unrelated fields (status, notes, etc.)
- Tight coupling to WorkSchedule makes testing harder
- Callbacks always fire, can't be easily disabled in tests
- Query could be expensive with complex WorkSchedule scopes
- No caching of work schedule lookup

**Real-World Impact**:
```ruby
# Every time you update an appointment, it queries work schedules:
appointment.update(status: :confirmed)  # ⚠️ Unnecessarily queries WorkSchedule!

# In tests, you must stub WorkSchedule queries or create full fixtures:
appointment = Appointment.create(...)  # Must have WorkSchedule in DB
```

**Proposed Solution**:

Move duration setting to a service object or explicit setter method. Only set duration on creation, not every update.

**Option 1: Service Object** (Recommended - 5 hours)
```ruby
# File: app/services/create_appointment_service.rb
class CreateAppointmentService
  def initialize(appointment_params, provider:, office:)
    @params = appointment_params
    @provider = provider
    @office = office
  end

  def call
    appointment = Appointment.new(@params.merge(
      provider: @provider,
      office: @office
    ))

    set_duration(appointment) if appointment.duration_minutes.blank?

    appointment.save ? Result.success(appointment) : Result.failure(appointment.errors)
  end

  private

  def set_duration(appointment)
    work_schedule = find_work_schedule(appointment)

    appointment.duration_minutes = if work_schedule
      work_schedule.slot_duration_minutes + work_schedule.slot_buffer_minutes
    else
      Appointment::DEFAULT_DURATION_MINUTES
    end
  end

  def find_work_schedule(appointment)
    WorkSchedule
      .active
      .for_provider(@provider.id)
      .for_office(@office.id)
      .for_day(appointment.scheduled_at.wday)
      .first
  end
end
```

**Option 2: before_create instead of before_save** (Simpler - 3 hours)
```ruby
# File: app/models/appointment.rb
# Change from before_save to before_create
before_create :set_duration_from_work_schedule, if: :duration_minutes_blank?

def duration_minutes_blank?
  duration_minutes.blank?
end

# Keep the existing set_duration_from_work_schedule method
```

**Implementation Steps**:

**For Option 1 (Service Object):**
1. **Create service object** - 2 hours
   - Create `app/services/create_appointment_service.rb`
   - Implement duration-setting logic
   - Create simple Result object for success/failure

2. **Update controllers** - 2 hours
   - Replace `Appointment.create` with `CreateAppointmentService.new(...).call`
   - Update error handling to use Result object
   - Update customer appointment creation flow

3. **Remove callback from model** - 30 minutes
   - Remove `before_save :set_duration_from_work_schedule`
   - Keep method as a public method for manual use if needed

4. **Update tests** - 1.5 hours
   - Create service object tests
   - Update controller tests to expect service usage
   - Simplify model tests (no need to stub WorkSchedule)

**For Option 2 (before_create):**
1. **Change callback** - 15 minutes
   - Replace `before_save` with `before_create`
   - Add conditional to skip if duration already set

2. **Update tests** - 1 hour
   - Verify callback only runs on create, not update
   - Test that manual duration setting is respected
   - Test fallback to default duration

3. **Add documentation** - 15 minutes
   - Document why before_create is used
   - Explain when duration is auto-set vs manual

**Better Code Example**:
```ruby
# BEFORE (runs on every save):
appointment.update(status: :confirmed)  # ⚠️ Queries WorkSchedule unnecessarily

# AFTER - Option 1 (Service Object):
result = CreateAppointmentService.new(
  appointment_params,
  provider: current_user,
  office: @office
).call

if result.success?
  @appointment = result.appointment
  redirect_to @appointment
else
  render :new
end

# AFTER - Option 2 (before_create):
appointment.update(status: :confirmed)  # ✅ No callback fires, just updates status
```

**Affected Files**:
- **Option 1**:
  - `app/services/create_appointment_service.rb` - **CREATE THIS FILE**
  - `app/models/appointment.rb` - Remove before_save callback
  - `app/controllers/customers/appointments_controller.rb` - Use service
  - `test/services/create_appointment_service_test.rb` - **CREATE THIS FILE**

- **Option 2**:
  - `app/models/appointment.rb` - Change callback from before_save to before_create
  - `test/models/appointment_test.rb` - Update tests

**Dependencies**:
- Blocks: None (but makes testing easier for other features)
- Blocked by: None
- Consider: This relates to the broader pattern of keeping models thin

**References**:
- [Rails Callbacks Guide](https://guides.rubyonrails.org/active_record_callbacks.html)
- [Service Objects in Rails](https://www.toptal.com/ruby-on-rails/rails-service-objects-tutorial)
- [When to avoid callbacks](https://samuelmullen.com/articles/guidelines-for-using-activerecord-callbacks/)

---

## Medium Priority Issues

### M1: Fat Model - WorkScheduleCollection

**Category**: Maintainability
**Effort**: ⏱️⏱️⏱️ Large (~8 hours)
**Impact**: 172-line form object still has multiple responsibilities

**Description**:
While WorkScheduleCollection has been significantly improved through recent refactoring (decomposed from 242 lines to 172 lines with service extraction), it still has room for simplification. The class mixes form object responsibilities with schedule lookup and error aggregation logic.

**Evidence**:
```ruby
# File: app/models/work_schedule_collection.rb (172 lines total)
class WorkScheduleCollection
  include ActiveModel::Model

  # Multiple responsibilities:
  # 1. Form object interface (lines 7-25)
  # 2. Validation aggregation (lines 64-84)
  # 3. Schedule lookup/access (lines 86-100)
  # 4. Params parsing coordination (lines 104-118)
  # 5. Update logic (lines 129-149)
  # 6. Service delegation (lines 151-171)
end
```

**Problem Analysis**:
- 172 lines for a "coordinator" class is still quite large
- Private methods doing work instead of just delegating (e.g., `update_schedules_from_params`)
- `update_schedules_from_params` (lines 133-149) has business logic about attribute assignment
- Mixes class methods (`self.load_schedules`) with instance methods
- Error aggregation logic (lines 72-80) could be extracted

**Proposed Solution**:

Further decompose by extracting error aggregation and schedule updating into separate classes.

**Implementation Steps**:
1. **Create ScheduleErrorAggregator** - 2 hours
   ```ruby
   # File: app/services/schedule_error_aggregator.rb
   class ScheduleErrorAggregator
     def initialize(schedules)
       @schedules = schedules
     end

     def aggregate_errors
       errors = ActiveModel::Errors.new(self)
       open_schedules = @schedules.select(&:is_active?)

       open_schedules.each do |schedule|
         next if schedule.errors.empty?

         day_name = schedule.day_name
         schedule.errors.full_messages.each do |message|
           errors.add(:base, "#{day_name}: #{message}")
         end
       end

       errors
     end
   end
   ```

2. **Create ScheduleUpdater service** - 2 hours
   ```ruby
   # File: app/services/schedule_updater.rb
   class ScheduleUpdater
     def initialize(current_schedules, new_params, office:, provider:)
       @current_schedules = current_schedules
       @new_params = new_params
       @office = office
       @provider = provider
     end

     def update
       parser = SchedulesFormDataParser.new(params: @new_params, office: @office, provider: @provider)
       updated_schedules = parser.parse

       @current_schedules.each_with_index do |schedule, index|
         updated_schedule = updated_schedules[index]
         schedule.assign_attributes(
           is_active: updated_schedule.is_active,
           work_periods: updated_schedule.work_periods,
           slot_duration_minutes: updated_schedule.slot_duration_minutes,
           slot_buffer_minutes: updated_schedule.slot_buffer_minutes,
           opening_time: updated_schedule.opening_time,
           closing_time: updated_schedule.closing_time
         )
       end

       @current_schedules
     end
   end
   ```

3. **Simplify WorkScheduleCollection** - 3 hours
   - Remove error aggregation logic, delegate to ScheduleErrorAggregator
   - Remove update logic, delegate to ScheduleUpdater
   - Result: Reduce to ~100 lines of pure coordination code

4. **Update tests** - 1 hour
   - Create tests for ScheduleErrorAggregator
   - Create tests for ScheduleUpdater
   - Update WorkScheduleCollection tests to verify delegation

**Better Code Example**:
```ruby
# BEFORE (172 lines with mixed responsibilities):
class WorkScheduleCollection
  def valid?
    open_schedules = schedules.select(&:is_active?)
    is_valid = open_schedules.all?(&:valid?)

    unless is_valid
      open_schedules.each do |schedule|
        # ... 8 lines of error aggregation logic
      end
    end
    is_valid
  end
end

# AFTER (~100 lines, pure coordination):
class WorkScheduleCollection
  def valid?
    open_schedules = schedules.select(&:is_active?)
    is_valid = open_schedules.all?(&:valid?)

    unless is_valid
      aggregated_errors = ScheduleErrorAggregator.new(open_schedules).aggregate_errors
      errors.merge!(aggregated_errors)
    end

    is_valid
  end
end
```

**Affected Files**:
- `app/services/schedule_error_aggregator.rb` - **CREATE THIS FILE**
- `app/services/schedule_updater.rb` - **CREATE THIS FILE**
- `app/models/work_schedule_collection.rb` - Simplify by delegating
- `test/services/schedule_error_aggregator_test.rb` - **CREATE THIS FILE**
- `test/services/schedule_updater_test.rb` - **CREATE THIS FILE**

**Dependencies**:
- Blocks: None
- Blocked by: None
- Note: This is an optimization, not a critical issue. The current code works well.

---

### M2: Missing Database Indexes

**Category**: Performance
**Effort**: ⏱️ Quick (~1.5 hours)
**Impact**: Slower queries as data grows, especially for filtered lists

**Description**:
Several columns are frequently queried but lack dedicated indexes. While some compound indexes exist, single-column indexes on frequently filtered fields would improve query performance.

**Evidence**:
```ruby
# Missing indexes for common query patterns:

# 1. work_schedules.is_active (queried alone frequently)
# File: app/models/work_schedule.rb:14
scope :active, -> { where(is_active: true) }
# Used in: AvailabilityService, WeeklyAvailabilityCalculator, controllers
# Current: Only compound indexes with is_active, no standalone index

# 2. office_memberships.role (filtered by role)
# File: app/models/office_membership.rb:25
scope :by_role, ->(role) { where(role: role) }
# Current: No index on role column

# 3. appointments - composite (status, scheduled_at)
# Pattern: Filtering by status AND ordering by scheduled_at
# Current: Separate indexes, but no composite for this common pattern
```

**Problem Analysis**:
- `WorkSchedule.active` is used in 6+ places but has no standalone `is_active` index
- `OfficeMembership.by_role` filters lack index support
- Appointments often filtered by status and ordered by scheduled_at (needs composite index)
- As data grows, these missing indexes will cause slow queries

**Proposed Solution**:

Add targeted indexes for these common query patterns.

**Implementation Steps**:
1. **Create migration for indexes** - 30 minutes
   ```ruby
   # File: db/migrate/XXXXXX_add_missing_indexes.rb
   class AddMissingIndexes < ActiveRecord::Migration[8.1]
     def change
       # Index for is_active on work_schedules (frequently queried alone)
       add_index :work_schedules, :is_active

       # Index for role on office_memberships
       add_index :office_memberships, :role

       # Composite index for common appointment query pattern
       add_index :appointments, [:status, :scheduled_at]
     end
   end
   ```

2. **Test query performance** - 30 minutes
   - Use `rails console` with query logging
   - Run common queries and check EXPLAIN output
   - Verify indexes are being used

3. **Run migration** - 10 minutes
   ```bash
   bin/rails db:migrate
   ```

4. **Update schema** - Auto-generated
   Schema will be updated automatically by migration

**Better Code Example**:
```sql
-- BEFORE (no index on is_active alone):
SELECT * FROM work_schedules WHERE is_active = true;
-- Seq Scan on work_schedules (slow for large tables)

-- AFTER (with index):
SELECT * FROM work_schedules WHERE is_active = true;
-- Index Scan using index_work_schedules_on_is_active (fast!)

-- BEFORE (filtering and ordering separately):
SELECT * FROM appointments WHERE status = 'confirmed' ORDER BY scheduled_at;
-- Uses index_appointments_on_status, then sorts

-- AFTER (composite index):
SELECT * FROM appointments WHERE status = 'confirmed' ORDER BY scheduled_at;
-- Index Scan using index_appointments_on_status_and_scheduled_at (faster!)
```

**Affected Files**:
- `db/migrate/XXXXXX_add_missing_indexes.rb` - **CREATE THIS FILE**
- `db/schema.rb` - Will be auto-updated after migration

**Dependencies**:
- Blocks: None
- Blocked by: None
- Note: Low risk, high reward. Can be done anytime.

**References**:
- [PostgreSQL EXPLAIN](https://www.postgresql.org/docs/current/sql-explain.html)
- [Rails Indexing Guide](https://guides.rubyonrails.org/active_record_migrations.html#creating-standalone-migrations)

---

### M3: Magic Numbers in Validations

**Category**: Maintainability
**Effort**: ⏱️⏱️ Medium (~2 hours)
**Impact**: Hard-coded values make intent unclear and changes difficult

**Description**:
String length validations and numeric constraints use hard-coded numbers (11, 100, 255, 500, etc.) without named constants. This makes it unclear why these specific values were chosen and harder to maintain consistency across the application.

**Evidence**:
```ruby
# File: app/models/user.rb:24
validates :cpf, length: { is: 11 }  # Why 11?

# File: app/models/work_schedule.rb:12
validates :day_of_week, numericality: {
  only_integer: true,
  greater_than_or_equal_to: 0,
  less_than_or_equal_to: 6  # Why 6? (Days in week - 1, but not obvious)
}

# File: app/models/office.rb:20-23
validates :name, length: { maximum: 255 }  # Standard DB limit, but not documented
validates :address, length: { maximum: 500 }
validates :city, length: { maximum: 100 }
validates :state, length: { maximum: 50 }
validates :postal_code, length: { maximum: 20 }
```

**Problem Analysis**:
- CPF length of 11 is Brazilian CPF format, but not obvious from code
- Day of week 0-6 maps to Sunday-Saturday, but requires domain knowledge
- String length limits (255, 500, 100) have no explanation
- If limits need to change, must find all occurrences
- No consistency checking (is postal_code always 20 across models?)

**Proposed Solution**:

Extract magic numbers to named constants with descriptive names.

**Implementation Steps**:
1. **Create constants in models** - 1 hour
   ```ruby
   # File: app/models/user.rb
   class User < ApplicationRecord
     CPF_LENGTH = 11  # Brazilian CPF format: XXX.XXX.XXX-XX (11 digits)
     MAX_NAME_LENGTH = 100
     MAX_PHONE_LENGTH = 20

     validates :cpf, length: { is: CPF_LENGTH }
     validates :first_name, :last_name, length: { maximum: MAX_NAME_LENGTH }
     validates :phone, length: { maximum: MAX_PHONE_LENGTH }
   end

   # File: app/models/work_schedule.rb
   class WorkSchedule < ApplicationRecord
     DAYS_IN_WEEK = 7
     LAST_DAY_OF_WEEK = DAYS_IN_WEEK - 1  # 6 (Saturday)

     validates :day_of_week, numericality: {
       only_integer: true,
       greater_than_or_equal_to: 0,
       less_than_or_equal_to: LAST_DAY_OF_WEEK
     }
   end

   # File: app/models/office.rb
   class Office < ApplicationRecord
     MAX_NAME_LENGTH = 255  # Standard VARCHAR limit
     MAX_ADDRESS_LENGTH = 500
     MAX_CITY_LENGTH = 100
     MAX_STATE_LENGTH = 50
     MAX_POSTAL_CODE_LENGTH = 20

     validates :name, length: { maximum: MAX_NAME_LENGTH }
     validates :address, length: { maximum: MAX_ADDRESS_LENGTH }
     validates :city, length: { maximum: MAX_CITY_LENGTH }
     validates :state, length: { maximum: MAX_STATE_LENGTH }
     validates :postal_code, length: { maximum: MAX_POSTAL_CODE_LENGTH }
   end
   ```

2. **Update other magic numbers** - 30 minutes
   ```ruby
   # File: app/services/availability_service.rb
   SECONDS_PER_MINUTE = 60
   minutes = (seconds / SECONDS_PER_MINUTE).to_i
   ```

3. **Update tests if needed** - 30 minutes
   - Tests can reference constants: `User::CPF_LENGTH`
   - Makes test intent clearer

**Better Code Example**:
```ruby
# BEFORE (unclear intent):
validates :cpf, length: { is: 11 }
validates :day_of_week, numericality: { less_than_or_equal_to: 6 }

# AFTER (self-documenting):
CPF_LENGTH = 11  # Brazilian CPF format
LAST_DAY_OF_WEEK = 6  # Saturday

validates :cpf, length: { is: CPF_LENGTH }
validates :day_of_week, numericality: { less_than_or_equal_to: LAST_DAY_OF_WEEK }
```

**Affected Files**:
- `app/models/user.rb` - Add constants for CPF, name, phone lengths
- `app/models/work_schedule.rb` - Add constants for days of week
- `app/models/office.rb` - Add constants for field lengths
- `app/models/office_membership.rb` - Add constant for role length
- `app/services/availability_service.rb` - Add SECONDS_PER_MINUTE (see H3)

**Dependencies**:
- Blocks: None
- Blocked by: None
- Related: H3 (also addresses SECONDS_PER_MINUTE magic number)

---

### M4: Unclear Method Naming in WorkSchedule

**Category**: Maintainability / Clarity
**Effort**: ⏱️ Quick (~1.5 hours)
**Impact**: Confusing method names that don't clearly indicate purpose

**Description**:
The `effective_opening_time` and `effective_closing_time` methods in WorkSchedule have vague names and inconsistent return types. The term "effective" is unclear, and the methods return different types (Time object vs String) depending on whether work_periods exist.

**Evidence**:
```ruby
# File: app/models/work_schedule.rb:94-105
def effective_opening_time
  return opening_time if work_periods.blank?
  work_periods.first&.dig("start")  # Returns String "09:00"
end

def effective_closing_time
  return closing_time if work_periods.blank?
  work_periods.last&.dig("end")  # Returns String "17:00"
end
```

**Problem Analysis**:
- "Effective" is vague - effective in what way? Compared to what?
- Returns different types: `Time` object (from opening_time) or `String` (from work_periods)
- Not clear these return first/last period times (not overall opening/closing)
- Comment says "for backward compatibility" but doesn't explain context
- Methods may be deprecated but no deprecation warning

**Proposed Solution**:

Rename methods to clearly indicate they return first/last period times, or deprecate if no longer needed.

**Implementation Steps**:
1. **Audit usage** - 30 minutes
   ```bash
   # Search for usage of these methods
   git grep "effective_opening_time"
   git grep "effective_closing_time"
   ```
   - Determine if methods are actually used
   - Check views, controllers, services

2. **Option A: Rename if used** - 45 minutes
   ```ruby
   # File: app/models/work_schedule.rb
   def first_period_start_time
     return opening_time if work_periods.blank?
     work_periods.first&.dig("start")
   end

   def last_period_end_time
     return closing_time if work_periods.blank?
     work_periods.last&.dig("end")
   end

   # Deprecated aliases for backward compatibility
   alias_method :effective_opening_time, :first_period_start_time
   alias_method :effective_closing_time, :last_period_end_time
   ```

3. **Option B: Remove if unused** - 15 minutes
   - If audit shows no usage, simply delete the methods
   - Remove tests for these methods

4. **Update callers** - 30 minutes
   - Replace old method calls with new method names
   - Update tests to use new names

**Better Code Example**:
```ruby
# BEFORE (vague naming):
def effective_opening_time
  return opening_time if work_periods.blank?
  work_periods.first&.dig("start")
end

# AFTER (clear intent):
def first_period_start_time
  return opening_time if work_periods.blank?
  work_periods.first&.dig("start")
end

# Usage is self-documenting:
schedule.first_period_start_time  # Ah, the start of the first period!
```

**Affected Files**:
- `app/models/work_schedule.rb` - Rename methods
- Search results from grep - Update callers
- `test/models/work_schedule_test.rb` - Update tests

**Dependencies**:
- Blocks: None
- Blocked by: None

---

### M5: Duplicate Code Pattern - activate!/deactivate!

**Category**: Code Duplication
**Effort**: ⏱️⏱️ Medium (~3 hours)
**Impact**: Same pattern repeated in multiple models

**Description**:
The `activate!` and `deactivate!` methods follow the same pattern in multiple models (WorkSchedule, OfficeMembership, potentially Office). This violates DRY and means changes to the pattern must be made in multiple places.

**Evidence**:
```ruby
# File: app/models/work_schedule.rb:113-119
def activate!
  update!(is_active: true)
end

def deactivate!
  update!(is_active: false)
end

# File: app/models/office_membership.rb:28-34
def activate!
  update!(is_active: true)
end

def deactivate!
  update!(is_active: false)
end
```

**Problem Analysis**:
- Identical implementation in 2+ models
- If we want to add callbacks or logging, must update multiple places
- Common pattern suggests this should be a shared concern
- All models with `is_active` column could benefit

**Proposed Solution**:

Extract to an `Activatable` concern.

**Implementation Steps**:
1. **Create Activatable concern** - 1 hour
   ```ruby
   # File: app/models/concerns/activatable.rb
   module Activatable
     extend ActiveSupport::Concern

     included do
       # Ensure the including model has an is_active column
       validates :is_active, inclusion: { in: [true, false] }

       # Scopes for active/inactive records
       scope :active, -> { where(is_active: true) }
       scope :inactive, -> { where(is_active: false) }
     end

     # Activate this record (sets is_active to true)
     # @return [Boolean] true if update succeeded
     # @raise [ActiveRecord::RecordInvalid] if validation fails
     def activate!
       update!(is_active: true)
     end

     # Deactivate this record (sets is_active to false)
     # @return [Boolean] true if update succeeded
     # @raise [ActiveRecord::RecordInvalid] if validation fails
     def deactivate!
       update!(is_active: false)
     end

     # Check if this record is active
     # @return [Boolean] true if is_active is true
     def active?
       is_active == true
     end

     # Check if this record is inactive
     # @return [Boolean] true if is_active is false
     def inactive?
       !active?
     end
   end
   ```

2. **Update models to use concern** - 1 hour
   ```ruby
   # File: app/models/work_schedule.rb
   class WorkSchedule < ApplicationRecord
     include Activatable  # ← Add this

     # Remove duplicate methods:
     # - activate!
     # - deactivate!
     # - active scope (now provided by concern)
   end

   # File: app/models/office_membership.rb
   class OfficeMembership < ApplicationRecord
     include Activatable  # ← Add this

     # Remove duplicate methods
   end

   # File: app/models/office.rb
   class Office < ApplicationRecord
     include Activatable  # ← Add this (if office has activate!/deactivate!)

     # Remove duplicate methods
   end
   ```

3. **Create tests** - 1 hour
   ```ruby
   # File: test/models/concerns/activatable_test.rb
   require "test_helper"

   class ActivatableTest < ActiveSupport::TestCase
     # Create a dummy model for testing
     class DummyActivatable
       include ActiveModel::Model
       include ActiveModel::Attributes
       include Activatable

       attribute :is_active, :boolean, default: false
     end

     test "activate! sets is_active to true" do
       record = DummyActivatable.new(is_active: false)
       record.activate!
       assert record.is_active
     end

     test "deactivate! sets is_active to false" do
       record = DummyActivatable.new(is_active: true)
       record.deactivate!
       refute record.is_active
     end

     test "active? returns true when is_active is true" do
       record = DummyActivatable.new(is_active: true)
       assert record.active?
     end

     test "inactive? returns true when is_active is false" do
       record = DummyActivatable.new(is_active: false)
       assert record.inactive?
     end
   end
   ```

4. **Verify existing tests still pass** - 30 minutes
   - Run model tests for WorkSchedule, OfficeMembership, Office
   - Ensure behavior hasn't changed

**Better Code Example**:
```ruby
# BEFORE (duplicated in each model):
class WorkSchedule < ApplicationRecord
  def activate!
    update!(is_active: true)
  end

  def deactivate!
    update!(is_active: false)
  end
end

class OfficeMembership < ApplicationRecord
  def activate!
    update!(is_active: true)
  end

  def deactivate!
    update!(is_active: false)
  end
end

# AFTER (DRY with concern):
class WorkSchedule < ApplicationRecord
  include Activatable
end

class OfficeMembership < ApplicationRecord
  include Activatable
end
```

**Affected Files**:
- `app/models/concerns/activatable.rb` - **CREATE THIS FILE**
- `app/models/work_schedule.rb` - Include concern, remove methods
- `app/models/office_membership.rb` - Include concern, remove methods
- `app/models/office.rb` - Include concern if applicable
- `test/models/concerns/activatable_test.rb` - **CREATE THIS FILE**

**Dependencies**:
- Blocks: None
- Blocked by: None

---

### M6: Inconsistent Hash Key Access

**Category**: Code Quality / Bugs
**Effort**: ⏱️ Quick (~1 hour)
**Impact**: Defensive code that might hide bugs

**Description**:
The SchedulesFormDataParser has defensive programming that checks for both string and symbol hash keys. This is unclear and might hide bugs where the wrong format is being passed.

**Evidence**:
```ruby
# File: app/services/schedules_form_data_parser.rb:79-83
periods_params.values.map do |period|
  {
    "start" => period[:start] || period["start"],
    "end" => period[:end] || period["end"]
  }
end
```

**Problem Analysis**:
- Unclear which format is expected (symbols or strings)
- No documentation explaining why both are needed
- Defensive code might hide bugs where wrong format is passed
- If only one format is actually used, the fallback is dead code

**Proposed Solution**:

Determine the actual input format, document it, and remove the defensive code.

**Implementation Steps**:
1. **Audit callers** - 20 minutes
   ```bash
   # Find where SchedulesFormDataParser is instantiated
   git grep "SchedulesFormDataParser.new"
   ```
   - Check what format params are in
   - Determine if it's always symbols, always strings, or mixed

2. **Document expected format** - 10 minutes
   ```ruby
   # File: app/services/schedules_form_data_parser.rb
   # @param params [Hash] Form params with string keys (Rails convention)
   #   Example: { "0" => { "start" => "09:00", "end" => "17:00" } }
   def initialize(params:, office:, provider:)
     # ...
   end
   ```

3. **Remove defensive code** - 20 minutes
   ```ruby
   # If params always have string keys:
   periods_params.values.map do |period|
     {
       "start" => period["start"],
       "end" => period["end"]
     }
   end

   # If params always have symbol keys:
   periods_params.values.map do |period|
     {
       "start" => period[:start],
       "end" => period[:end]
     }
   end
   ```

4. **Add tests to verify format** - 10 minutes
   - Test with string keys (Rails params default)
   - Test should fail if wrong format is passed (intentionally)

**Better Code Example**:
```ruby
# BEFORE (unclear, defensive):
{
  "start" => period[:start] || period["start"],  # Which format?
  "end" => period[:end] || period["end"]
}

# AFTER (clear, intentional):
# With documentation showing params are strings from Rails forms
{
  "start" => period["start"],  # Rails params use string keys
  "end" => period["end"]
}
```

**Affected Files**:
- `app/services/schedules_form_data_parser.rb` - Document format, remove defensive code
- `test/services/schedules_form_data_parser_test.rb` - **CREATE THIS FILE** with format tests

**Dependencies**:
- Blocks: None
- Blocked by: L6 (would be easier with tests in place first)

---

### M7: Missing Scopes for Common Queries

**Category**: Maintainability
**Effort**: ⏱️⏱️ Medium (~2.5 hours)
**Impact**: Repeated query chains reduce readability

**Description**:
Several models have common query patterns that are repeated across the codebase. These should be extracted into named scopes for better readability and consistency.

**Evidence**:
```ruby
# Missing scopes for User model:
# No scope for users who are providers
current_user.offices.exists?  # Repeated pattern for checking provider status

# Missing scopes for WorkSchedule:
# Common pattern: chain active, provider, office, and day
WorkSchedule.active.for_provider(id).for_office(id).for_day(day)
# Could be: WorkSchedule.active_for(provider: id, office: id, day: day)

# Missing scopes for Appointment:
# Pattern: by status and date range together
Appointment.where(status: :confirmed).where(scheduled_at: date_range)
```

**Problem Analysis**:
- Query chains are verbose and repeated
- Intent is not immediately clear from chained where clauses
- Changes to query logic require updates in multiple places
- No consistent way to fetch related data

**Proposed Solution**:

Add composite scopes for common query patterns.

**Implementation Steps**:
1. **Add User provider scopes** - 30 minutes
   ```ruby
   # File: app/models/user.rb
   # Check if user is a provider (manages at least one office)
   scope :providers, -> { joins(:office_memberships).where(office_memberships: { is_active: true }).distinct }

   # Instance method alternative
   def provider?
     offices.exists?
   end
   ```

2. **Add WorkSchedule composite scope** - 45 minutes
   ```ruby
   # File: app/models/work_schedule.rb
   # Find active schedule for specific provider, office, and day
   # @param provider [User, Integer] Provider or provider ID
   # @param office [Office, Integer] Office or office ID
   # @param day [Integer] Day of week (0-6)
   # @return [ActiveRecord::Relation]
   scope :active_for, ->(provider:, office:, day:) {
     active
       .for_provider(provider.is_a?(User) ? provider.id : provider)
       .for_office(office.is_a?(Office) ? office.id : office)
       .for_day(day)
   }
   ```

3. **Add Appointment composite scopes** - 45 minutes
   ```ruby
   # File: app/models/appointment.rb
   # Appointments by status within date range
   scope :by_status_in_range, ->(status, start_date, end_date) {
     by_status(status).where(scheduled_at: start_date..end_date)
   }

   # Confirmed appointments in date range (common pattern)
   scope :confirmed_in_range, ->(start_date, end_date) {
     by_status_in_range(:confirmed, start_date, end_date)
   }
   ```

4. **Update callers to use new scopes** - 30 minutes
   - Search for repeated query patterns
   - Replace with new scopes
   - Verify behavior hasn't changed

5. **Add tests** - 30 minutes
   - Test each new scope returns correct results
   - Test edge cases (nil values, empty results)

**Better Code Example**:
```ruby
# BEFORE (verbose chains):
work_schedule = WorkSchedule
  .active
  .for_provider(provider.id)
  .for_office(office.id)
  .for_day(scheduled_at.wday)
  .first

# AFTER (clear intent):
work_schedule = WorkSchedule.active_for(
  provider: provider,
  office: office,
  day: scheduled_at.wday
).first

# BEFORE (checking provider status):
if current_user.offices.exists?
  # provider logic
end

# AFTER (self-documenting):
if current_user.provider?
  # provider logic
end
```

**Affected Files**:
- `app/models/user.rb` - Add provider scopes
- `app/models/work_schedule.rb` - Add composite scope
- `app/models/appointment.rb` - Add date range scopes
- Controllers and services using these queries - Update to use scopes
- Test files - Add scope tests

**Dependencies**:
- Blocks: None
- Blocked by: None
- Related: L9 (provider? method)

---

## Low Priority Issues

### L1: Boolean Trap in GeocodeOfficeService

**Category**: Code Quality
**Effort**: ⏱️⏱️ Medium (~2 hours)
**Impact**: Constructor parameter intent unclear at call site

**Description**:
The `GeocodeOfficeService` has a boolean parameter `geocoding_enabled` that isn't clear at the call site. This is a "boolean trap" where the purpose of `true` or `false` isn't obvious without looking at the method signature.

**Evidence**:
```ruby
# File: app/services/geocode_office_service.rb:2
def initialize(office, geocoding_enabled: Rails.application.config.geocoding_enabled)
  @office = office
  @geocoding_enabled = geocoding_enabled
end

# Usage (unclear):
GeocodeOfficeService.new(office, geocoding_enabled: false)  # Why false?
```

**Proposed Solution**:
Use a null object or strategy pattern for clearer intent.

**Implementation**:
```ruby
# Option 1: Null Object
class GeocodeOfficeService
  def self.call(office)
    if Rails.application.config.geocoding_enabled
      RealGeocoder.new(office).call
    else
      NullGeocoder.new(office).call
    end
  end
end

# Option 2: Named constructor methods
class GeocodeOfficeService
  def self.with_geocoding(office)
    new(office, geocoder: RealGeocoder.new)
  end

  def self.without_geocoding(office)
    new(office, geocoder: NullGeocoder.new)
  end
end
```

**Affected Files**:
- `app/services/geocode_office_service.rb`

---

### L2: Inconsistent Default Duration Constants

**Category**: Code Duplication
**Effort**: ⏱️ Quick (~30 minutes)
**Impact**: Two sources of truth for same value

**Description**:
Default appointment duration is defined in two places: `Appointment::DEFAULT_DURATION_MINUTES` and `SchedulingDefaults::DEFAULT_APPOINTMENT_DURATION`.

**Evidence**:
```ruby
# File: app/models/appointment.rb:2
DEFAULT_DURATION_MINUTES = 50

# File: config/initializers/scheduling_defaults.rb:7
DEFAULT_APPOINTMENT_DURATION = 50
```

**Proposed Solution**:
Use only SchedulingDefaults and reference it from Appointment.

**Implementation**:
```ruby
# File: app/models/appointment.rb
DEFAULT_DURATION_MINUTES = SchedulingDefaults::DEFAULT_APPOINTMENT_DURATION

# Or remove constant entirely and use SchedulingDefaults directly
```

**Affected Files**:
- `app/models/appointment.rb` - Update constant reference

---

### L3: Complex Conditional in AvailabilityCalendar

**Category**: Code Quality
**Effort**: ⏱️ Quick (~1 hour)
**Impact**: Should use model scopes instead of raw SQL

**Description**:
AvailabilityCalendar builds queries with raw SQL-style conditions instead of using model scopes.

**Evidence**:
```ruby
# File: app/models/availability_calendar.rb:22-24
schedules = work_schedules || WorkSchedule.where(office_id: self.office_id, is_active: true)
appointments = Appointment.where(office_id: self.office_id, scheduled_at: self.period_start..self.period_end)
                          .where.not(status: :cancelled)
```

**Proposed Solution**:
Use model scopes for clarity.

**Implementation**:
```ruby
# AFTER:
schedules = work_schedules || WorkSchedule.for_office(office_id).active
appointments = Appointment
  .for_office(office_id)
  .blocking_time
  .between(period_start, period_end)
```

**Affected Files**:
- `app/models/availability_calendar.rb`

---

### L4: Typo in Comment

**Category**: Documentation
**Effort**: ⏱️ Quick (~5 minutes)
**Impact**: Minor documentation quality issue

**Evidence**:
```ruby
# File: app/services/weekly_availability_calculator.rb:123
# Number of available (unboo ked) slots
```

**Fix**:
```ruby
# Number of available (unbooked) slots
```

---

### L5: Unused Private Method

**Category**: Dead Code
**Effort**: ⏱️ Quick (~10 minutes)
**Impact**: Confusing unused code

**Description**:
The `deactivate_existing_schedules` private method in SchedulesPersistenceService is defined but never called.

**Evidence**:
```ruby
# File: app/services/schedules_persistence_service.rb:69-74
def deactivate_existing_schedules
  office.work_schedules
        .active
        .for_provider(provider.id)
        .update_all(is_active: false)
end
```

**Proposed Solution**:
Remove the method or use it if it was intended.

---

### L6: Missing Tests for Services and Concerns

**Category**: Testing
**Effort**: ⏱️⏱️⏱️ Large (~12 hours)
**Impact**: Critical services lack test coverage

**Description**:
Three services and one concern are missing test files entirely.

**Missing Tests**:
- `test/services/schedules_persistence_service_test.rb` - **DOES NOT EXIST**
- `test/services/schedules_loader_test.rb` - **DOES NOT EXIST**
- `test/services/schedules_form_data_parser_test.rb` - **DOES NOT EXIST**
- `test/models/concerns/membership_management_test.rb` - **DOES NOT EXIST**

**Proposed Solution**:
Create comprehensive test files for each.

**Effort Breakdown**:
- SchedulesPersistenceService tests: 4 hours
- SchedulesLoader tests: 3 hours
- SchedulesFormDataParser tests: 3 hours
- MembershipManagement tests: 2 hours

---

### L7: Hard-coded Pagination Limits

**Category**: Configuration
**Effort**: ⏱️ Quick (~1 hour)
**Impact**: Magic numbers for pagination

**Evidence**:
```ruby
# File: app/controllers/customers/appointments_controller.rb:6
@past_appointments = current_user.appointments.past.limit(10)

# File: app/controllers/providers/dashboard_controller.rb:13,18
.limit(20)  # Appears twice
```

**Proposed Solution**:
Extract to constants.

**Implementation**:
```ruby
# In controller or config
PAST_APPOINTMENTS_LIMIT = 10
DEFAULT_PAGE_SIZE = 20

@past_appointments = current_user.appointments.past.limit(PAST_APPOINTMENTS_LIMIT)
```

---

### L8: Missing Eager Loading in Controllers

**Category**: Performance
**Effort**: ⏱️ Quick (~1 hour)
**Impact**: Potential N+1 queries in views

**Evidence**:
```ruby
# File: app/controllers/customers/appointments_controller.rb:5-6
@upcoming_appointments = current_user.appointments.upcoming
@past_appointments = current_user.appointments.past.limit(10)
# Missing: .includes(:office, :provider)
```

**Proposed Solution**:
Add eager loading.

**Implementation**:
```ruby
@upcoming_appointments = current_user.appointments.upcoming
  .includes(:office, :provider)
@past_appointments = current_user.appointments.past
  .includes(:office, :provider)
  .limit(10)
```

---

### L9: Duplicate Role Checking Pattern

**Category**: Code Duplication
**Effort**: ⏱️ Quick (~1 hour)
**Impact**: Same logic repeated 4+ times

**Description**:
The pattern `current_user.offices.exists?` is repeated across helpers and controllers to check if a user is a provider.

**Evidence**:
```ruby
# File: app/helpers/application_helper.rb:5
user_signed_in? && current_user.offices.exists?

# File: app/controllers/providers/dashboard_controller.rb:26
unless current_user.offices.exists?

# File: app/controllers/customers/appointments_controller.rb:7
@has_provider_access = current_user.offices.exists?
```

**Proposed Solution**:
Add `provider?` method to User model.

**Implementation**:
```ruby
# File: app/models/user.rb
def provider?
  offices.exists?
end

# Usage:
current_user.provider?  # Clear and DRY
```

**Affected Files**:
- `app/models/user.rb` - Add method
- All files checking `offices.exists?` - Replace with `provider?`

---

## Prevention Patterns

### Service Object Pattern

**When to use**: Extracting complex business logic from models or controllers

**Example from codebase**:
```ruby
# Good example: app/services/weekly_availability_calculator.rb
class WeeklyAvailabilityCalculator
  def initialize(office:, provider:, week_start:)
    @office = office
    @provider = provider
    @week_start = week_start
  end

  def call
    # Single public method for execution
    # Returns a result hash
  end

  private
  # Private methods for decomposition
end

# Usage:
result = WeeklyAvailabilityCalculator.new(
  office: @office,
  provider: current_user,
  week_start: Date.today.beginning_of_week
).call
```

**Best practices**:
- Single public method (`call` or `perform`)
- Dependencies injected via constructor
- Returns result object or hash
- Keep under 150 lines
- One responsibility per service

---

### Value Object Pattern

**When to use**: Encapsulating data with behavior, immutable data structures

**Example from codebase**:
```ruby
# Good example: app/values/time_period.rb
TimePeriod = Data.define(:start_time, :end_time) do
  def duration
    return 0 unless start_time && end_time
    end_time - start_time
  end

  def overlaps?(other)
    # Domain logic encapsulated in value object
  end
end

# Usage:
period = TimePeriod.new(start_time: Time.parse("09:00"), end_time: Time.parse("17:00"))
period.duration  # Returns seconds
```

**Best practices**:
- Use `Data.define` for immutability
- Add domain-specific methods
- Keep them small and focused
- No persistence logic

---

### Concern Extraction

**When to use**: Sharing behavior across multiple models

**Example from codebase**:
```ruby
# Good example: app/models/concerns/temporal_scopes.rb
module TemporalScopes
  extend ActiveSupport::Concern

  included do
    # Define class methods available to includers
  end

  class_methods do
    def temporal_scope_field(field_name)
      scope :upcoming, -> { where("#{field_name} > ?", Time.current) }
      scope :past, -> { where("#{field_name} <= ?", Time.current) }
    end
  end
end

# Usage:
class Appointment < ApplicationRecord
  include TemporalScopes
  temporal_scope_field :scheduled_at
end
```

**Best practices**:
- Use when 3+ models need same behavior
- Clear single responsibility
- Document what the concern provides
- Test concerns independently

---

### Code Review Checklist

Use this checklist when reviewing PRs:

**Architecture**:
- [ ] No business logic in controllers (use services)
- [ ] Services are < 150 lines with single responsibility
- [ ] Models are < 200 lines (extract concerns if needed)
- [ ] Value objects used for data+behavior
- [ ] Concerns used for shared model behavior

**Performance**:
- [ ] Eager loading used for associations (`.includes()`)
- [ ] No N+1 queries (test with Bullet gem)
- [ ] Database indexes exist for queried columns
- [ ] No database queries in callbacks
- [ ] Pagination on list actions

**Code Quality**:
- [ ] No magic numbers (use named constants)
- [ ] Clear method names (no `effective_*`, `do_*`, `handle_*`)
- [ ] No boolean traps (unclear true/false parameters)
- [ ] Hash keys consistent (symbols or strings, not both)
- [ ] DRY - no duplicate code blocks

**Testing**:
- [ ] New services have test files
- [ ] New concerns have test files
- [ ] Controllers test happy path + error cases
- [ ] Edge cases covered (nil, empty, boundary values)
- [ ] Integration tests for critical user flows

---

## References

### Internal Documentation
- [CLAUDE.md](./CLAUDE.md) - Architecture overview and development guide
- [README.md](./README.md) - Setup and development workflow

### External Resources
- [Refactoring: Ruby Edition](https://martinfowler.com/books/refactoringRubyEd.html) - Martin Fowler
- [Rails Service Objects Tutorial](https://www.toptal.com/ruby-on-rails/rails-service-objects-tutorial)
- [Rails Anti-Patterns](https://www.codeguru.com/dotnet/rails-anti-patterns/)
- [Rubocop Rails Omakase](https://github.com/rails/rubocop-rails-omakase) - Style guide used in this project
- [Better Specs](https://www.betterspecs.org/) - RSpec best practices (adaptable to Minitest)

### Performance Tools
- [Bullet Gem](https://github.com/flyerhzm/bullet) - N+1 query detection
- [PostgreSQL EXPLAIN](https://www.postgresql.org/docs/current/sql-explain.html) - Query analysis
- [Rails Query Optimization](https://guides.rubyonrails.org/active_record_querying.html#eager-loading-associations)

### Project Metrics
- Total Lines of Ruby Code: ~3,500
- Test Coverage: ~85% (estimated based on test file count)
- Average Service Size: ~100 lines
- Files with Tests: 32/40 (80%)
- Active Code Smells: 20 (4 High, 7 Medium, 9 Low)

---

**Last Updated**: December 5, 2025
**Next Review**: January 5, 2026

**Quick Wins to Start**: L4 (typo fix), L5 (remove unused method), L2 (consolidate constants)

# README

This README would normally document whatever steps are necessary to get the
application up and running.

Things you may want to cover:

* Ruby version

* System dependencies

* Configuration

* Database creation

* Database initialization

* How to run the test suite

* Services (job queues, cache servers, search engines, etc.)

* Deployment instructions

* ...

---

## Architecture & Design Patterns

### Value Objects

This application uses Ruby's `Data.define` to create immutable value objects that encapsulate related data and behavior. Value objects improve encapsulation and reduce coupling between layers.

#### TimePeriod (`app/values/time_period.rb`)

Encapsulates a time range with utility methods for overlap detection and duration calculation:

```ruby
period = TimePeriod.new(start_time: 9.am, end_time: 5.pm)
period.duration        # => duration in seconds
period.overlaps?(other_period)  # => true/false
period.contains?(time)          # => true/false
```

**Used by:**
- `Appointment#time_range` - Returns appointment time as TimePeriod
- `WorkSchedule#periods_for_date` - Returns work periods as TimePeriod array
- `AvailabilityService` - Calculates available time slots
- `PeriodSubtractorService` - Handles complex time subtraction logic

#### SlotConfiguration (`app/values/slot_configuration.rb`)

Bundles slot generation parameters together:

```ruby
config = work_schedule.slot_configuration_for_date(date)
config.duration             # => appointment duration (e.g., 50.minutes)
config.buffer              # => buffer time (e.g., 10.minutes)
config.periods             # => array of TimePeriod objects
config.total_slot_duration # => duration + buffer
```

**Used by:**
- `WorkSchedule#slot_configuration_for_date` - Encapsulates scheduling configuration
- `SlotGenerator` - Generates available appointment slots based on configuration

### Service Layer Organization

Services follow the Single Responsibility Principle and compose well:

```
WeeklyAvailabilityCalculator (orchestrator)
  ├─> WorkSchedule (queries)
  ├─> Appointment (queries)
  └─> SlotGenerator → AvailableSlot[]

AvailabilityService
  ├─> WorkSchedule#periods_for_date → TimePeriod[]
  ├─> Appointment#time_range → TimePeriod
  └─> PeriodSubtractorService → TimePeriod[]

SlotGenerator
  ├─> WorkSchedule#slot_configuration_for_date → SlotConfiguration
  ├─> OverlapChecker → Boolean
  └─> AvailableSlot[]
```

### Benefits of This Architecture

1. **Encapsulation:** Models encapsulate their data and provide high-level interfaces through value objects
2. **Reduced Coupling:** Services depend on abstractions (value objects) not implementation details
3. **Testability:** Value objects and services can be tested independently with clear boundaries
4. **Maintainability:** Changes to internal logic don't ripple through the codebase
5. **Type Safety:** Value objects provide clear contracts for data exchange between layers
6. **Immutability:** Using `Data.define` ensures value objects are immutable by default

### Key Principles

- **Tell, Don't Ask:** Services tell models what to do, don't ask for their data
- **Value Objects:** Use immutable objects for data transfer between layers
- **Single Responsibility:** Each class has one clear, well-defined purpose
- **Composition:** Complex behavior built from simple, composable pieces
- **Dependency Direction:** Services depend on models, never the reverse

### Code Quality

See `CODE_SMELLS.md` for detailed analysis of code quality improvements, including resolved Feature Envy issues and architectural patterns.

<!-- OPENSPEC:START -->
# OpenSpec Instructions

These instructions are for AI assistants working in this project.

Always open `@/openspec/AGENTS.md` when the request:
- Mentions planning or proposals (words like proposal, spec, change, plan)
- Introduces new capabilities, breaking changes, architecture shifts, or big performance/security work
- Sounds ambiguous and you need the authoritative spec before coding

Use `@/openspec/AGENTS.md` to learn:
- How to create and apply change proposals
- Spec format and conventions
- Project structure and guidelines

Keep this managed block so 'openspec update' can refresh the instructions.

<!-- OPENSPEC:END -->

# CLAUDE.md

This file provides guidance to Claude Code (claude.ai/code) when working with code in this repository.

## Application Overview

**Marque Um Horário** is a Brazilian appointment scheduling and booking system. The application enables providers (service providers/professionals) to manage work schedules across multiple offices, and customers to book appointments with providers. The system automatically calculates availability considering work hours, breaks, and existing appointments.

**Technology Stack:**
- Rails 8.1.1 with PostgreSQL (UUID primary keys)
- Hotwire (Turbo + Stimulus) for dynamic interactions
- Tailwind CSS for styling
- Devise for authentication
- Solid Stack gems (solid_cache, solid_queue, solid_cable)
- Geocoder for office location services

## Common Commands

### Development Setup
```bash
bin/setup                    # Initial setup (installs deps, prepares DB, starts server)
bin/setup --reset            # Reset and recreate database
bin/setup --skip-server      # Setup without starting server
```

### Running the Application
```bash
bin/dev                      # Start Rails server + Tailwind watcher (uses foreman)
bin/rails server             # Start Rails server only
bin/rails tailwindcss:watch  # Watch and compile Tailwind CSS
```

### Testing
```bash
bin/rails test                    # Run all unit tests
bin/rails test:system             # Run system tests (Capybara)
bin/rails test test/models/user_test.rb          # Run single test file
bin/rails test test/models/user_test.rb:12       # Run single test by line number
```

### Code Quality & Security
```bash
bin/rubocop                  # Run Ruby style linter (omakase style)
bin/rubocop -a               # Auto-fix style issues
bin/brakeman                 # Security vulnerability scanner
bin/bundler-audit            # Check gems for known vulnerabilities
bin/importmap audit          # Check importmap dependencies
bin/ci                       # Run full CI suite (setup, lint, security, tests)
```

### Database
```bash
bin/rails db:prepare         # Create/migrate database
bin/rails db:reset           # Drop, create, migrate, and seed database
bin/rails db:migrate         # Run pending migrations
bin/rails db:rollback        # Rollback last migration
bin/rails db:seed            # Load seed data
```

## Architecture

### Domain Model - Role-Based Multi-Tenant System

**Core Entities:**
- **Users**: Dual-role system (provider, customer, or both). Uses Devise for authentication with implicit role determination via associations.
- **Offices**: Physical/virtual locations where services are provided. Supports geocoding, timezone-aware scheduling, and multi-provider management.
- **WorkSchedules**: Provider availability templates. Day-based (0-6 = Sunday-Saturday) with support for complex work periods (lunch breaks, multiple shifts). Defines appointment duration and buffer times.
- **Appointments**: Bookings with status tracking (pending, confirmed, cancelled, completed). End time calculated based on duration + buffer.
- **OfficeMemberships**: Join table connecting users to offices with role-based permissions (member, admin, owner).
- **AvailabilityCalendars**: Pre-computed cache of available and busy periods for performance optimization.

### Availability Calculation Engine (Core Business Logic)

The availability calculation is the heart of the system, using a **3-layer architecture**:

1. **WorkSchedule (Foundation)**: Defines when a provider works. Stores `work_periods` as JSON array allowing breaks:
   ```ruby
   work_periods: [
     { "start" => "09:00", "end" => "12:00" },  # Morning shift
     { "start" => "13:00", "end" => "17:00" }   # Afternoon shift
   ]
   ```

2. **AvailabilityService (Calculation)**: Subtracts booked appointments from work periods. Core algorithm `subtract_time_range()` handles 5 overlap cases: no overlap, complete overlap, overlaps start, overlaps end, and middle overlap (splits period). Located in `app/services/availability_service.rb`.

3. **SlotGenerator (Discretization)**: Converts availability into fixed-size appointment slots. Uses `AvailableSlot` value object with status ("available"/"busy"). Respects buffer time between appointments. Located in `app/services/slot_generator.rb`.

**Supporting Services:**
- `OverlapChecker` (app/services/overlap_checker.rb): Centralized interval overlap detection logic.

### Authentication & Authorization

**Devise Integration:**
- Email-based authentication with trackable module (sign_in_count, last_sign_in_at, last_sign_in_ip)
- Custom permitted parameters: first_name, last_name, phone, cpf
- All controllers use `before_action :authenticate_user!` for authentication

**Implicit Dual-Role System:**

The system does NOT use an explicit `roles` column. Instead, user capabilities are determined implicitly through associations:

```ruby
# Provider capability: User manages at least one office
current_user.offices.exists?  # → true means user can access provider features

# Customer capability: User has booked appointments
current_user.appointments.exists?  # → true means user has booking history

# Provider appointments: Appointments where user is the service provider
current_user.provider_appointments.exists?  # → true means user has provider bookings

# Dual-role: User can have both provider and customer capabilities simultaneously
```

**How Authorization Works:**

Access control is implemented through **association scoping** rather than explicit role checks:

```ruby
# Provider controllers scope to offices user manages
current_user.offices                    # Only offices where user is a member
current_user.provider_appointments      # Only appointments where user is provider
current_user.work_schedules             # Only user's work schedules

# Customer controllers scope to appointments user booked
current_user.appointments               # Only appointments where user is customer

# Provider access guard (example from Providers::DashboardController)
def ensure_has_office
  unless current_user.offices.exists?
    redirect_to new_providers_onboarding_path,
      notice: "Welcome! Let's create your first office to get started."
  end
end
```

**Office-Level Roles:**

In addition to user capabilities, `office_memberships` has granular permissions:

```ruby
# office_memberships.role values:
- "owner"   # Full control, can delete office
- "admin"   # Can manage schedules and appointments
- "member"  # Can view office data (default)

# Example usage:
office_membership = current_user.office_memberships.find_by(office: office)
office_membership.role  # → "owner", "admin", or "member"
```

**User Model Helper Methods:**

```ruby
# app/models/user.rb
user.full_name              # Returns "FirstName LastName"
user.manages_office?(office) # Check if user has membership to office
user.add_office(office)      # Add user to office
user.remove_office(office)   # Remove user from office
```

**Business Rules:**
- Any authenticated user can book appointments (customer capability)
- Only users with office memberships can access provider features
- Office access is checked via `current_user.offices` scoping
- CPF (Brazilian ID) is optional but unique when provided (normalized to digits-only)
- Users can act as both provider and customer simultaneously

### Reusable Patterns

**TemporalScopes Concern** (app/models/concerns/temporal_scopes.rb):
Provides queryable temporal scopes for models with datetime fields:
```ruby
include TemporalScopes
temporal_scope_field :scheduled_at

# Auto-generates: upcoming, past, today, between(start, end), on_date(date)
```

**TimeRangeValidator** (app/validators/time_range_validator.rb):
Custom ActiveModel validator ensuring start_time < end_time:
```ruby
validates_with TimeRangeValidator, start: :opening_time, end: :closing_time
```

### Database Design

**UUID Primary Keys**: All tables use PostgreSQL `gen_random_uuid()` for distributed system readiness and security.

**Composite Indexes for Performance**:
- Appointments: (customer_id, scheduled_at), (provider_id, status), (office_id, scheduled_at) - enables efficient filtering + sorting
- WorkSchedules: Unique constraint on (provider_id, office_id, day_of_week) when is_active=true - allows versioning

**JSON Storage**: WorkSchedules use JSONB `work_periods` with GIN index for complex queries.

**Soft-Delete Pattern**: `is_active` boolean flags on offices, office_memberships, and work_schedules for audit trails.

### Architectural Decisions

1. **Enum-Based Status Management**: String-based enums (not integers) with validation. Provides bang methods: `appointment.confirmed!`.

2. **Multi-Office Provider Model**: Single provider can manage multiple offices with different schedules per office per day.

3. **Appointment Duration Storage**: Appointment duration is stored in `appointments.duration_minutes` column (default: 50 minutes). Duration is automatically set from the provider's WorkSchedule via `before_save` callback, but can be customized per appointment if needed. This provides consistency while allowing flexibility.

4. **Timezone-Aware Scheduling**: Each office has `time_zone` attribute (ActiveSupport::TimeZone) for correct cross-timezone scheduling.

5. **Single Provider per Appointment**: Appointments have one provider, not multiple providers for same slot.

6. **Work Schedule Active-Based Versioning**: Only one active schedule per provider per day per office (allows drafts/versioning of schedules).

## Test Structure

**Framework**: Rails minitest with fixtures and parallel execution.

**Test Organization**:
- `test/models/` - Unit tests for Active Record models
- `test/models/concerns/` - Tests for model concerns
- `test/services/` - Unit tests for service objects
- `test/system/` - End-to-end browser tests (Capybara + Selenium)
- `test/fixtures/` - YAML fixture data

**Key Testing Patterns**:
- Fixture-driven tests with Devise encrypted passwords
- Service objects are isolated and tested independently
- Comprehensive validation coverage including edge cases
- Parallel test execution enabled (uses number of processors)

**Important Fixtures**:
- Users: `provider_john`, `provider_jane`, `customer_alice`, `customer_bob`, `provider_customer_charlie` (dual-role)
- Offices: `main_office` (NYC), `west_coast_office` (LA)
- WorkSchedules: Multiple schedules with work_periods demonstrating lunch breaks
- Appointments: Various statuses (pending, confirmed, cancelled, completed) and dates

**Running Single Tests**:
```bash
# Run specific test file
bin/rails test test/services/availability_service_test.rb

# Run specific test by line number
bin/rails test test/models/appointment_test.rb:45
```

## Development Workflow

### CI Pipeline
The `bin/ci` script runs the full CI suite:
1. Setup (bin/setup --skip-server)
2. Ruby style check (bin/rubocop)
3. Security: Gem audit (bin/bundler-audit)
4. Security: Importmap audit (bin/importmap audit)
5. Security: Brakeman code analysis (bin/brakeman)
6. Tests: Rails (bin/rails test)
7. Tests: System (bin/rails test:system)
8. Tests: Seeds (test db:seed:replant)

### Code Style
- Follows Rails Omakase Ruby styling (rubocop-rails-omakase)
- Configuration in `.rubocop.yml`

### Key Constraints

1. **No Recurring Appointments**: Each booking is discrete (no repeat patterns in database)
2. **Office is Required**: All appointments must be tied to an office (enables multi-location scheduling)
3. **Work Period Validation**: Appointment duration must fit within work day, no overlapping work periods
4. **Active Schedule Uniqueness**: Only one active schedule per provider per day per office
5. **Status Transitions**: Appointments follow lifecycle: pending → confirmed → completed (or cancelled from any state)
   - **Confirmed**: Sets `confirmed_at` timestamp.
   - **Cancelled**:
     - By Customer: Sets status to cancelled.
     - By Provider (Decline): Sets status to cancelled, `declined_at` timestamp, and requires `decline_reason`.

## Important Entry Points

**Core Models**: `app/models/user.rb`, `app/models/office.rb`, `app/models/appointment.rb`, `app/models/work_schedule.rb`

**Business Logic**: `app/services/availability_service.rb`, `app/services/slot_generator.rb`, `app/services/overlap_checker.rb`

**Authentication**: `app/controllers/application_controller.rb` (Devise integration, configure_permitted_parameters)

**Reusable Concerns**: `app/models/concerns/temporal_scopes.rb`

**Custom Validators**: `app/validators/time_range_validator.rb`

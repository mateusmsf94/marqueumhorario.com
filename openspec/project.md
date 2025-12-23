# Project Context

## Purpose
**Marque Um Horário** is a Brazilian appointment scheduling and booking system. The application enables service providers (professionals) to manage work schedules across multiple offices, and customers to book appointments with providers. The system automatically calculates availability considering work hours, breaks, and existing appointments.

**Key Goals:**
- Multi-office provider management with timezone-aware scheduling
- Intelligent availability calculation that handles complex work periods (lunch breaks, multiple shifts)
- Dual-role user system (users can be both providers and customers)
- Real-time appointment booking with conflict prevention

## Tech Stack

**Core Framework:**
- Rails 8.1.1 with PostgreSQL (UUID primary keys)
- Ruby 3.x

**Frontend:**
- Hotwire (Turbo + Stimulus) for dynamic interactions
- Tailwind CSS for styling
- Importmap for JavaScript modules

**Authentication & Authorization:**
- Devise for user authentication
- Implicit role-based authorization via associations (no explicit roles column)

**Infrastructure:**
- Solid Stack gems: solid_cache, solid_queue, solid_cable
- Geocoder for office location services
- Puma web server
- Propshaft asset pipeline

**Development Tools:**
- Minitest with fixtures for testing
- Capybara + Selenium for system tests
- RuboCop (Omakase style)
- Brakeman for security scanning
- Bundler Audit for gem vulnerability scanning

## Project Conventions

### Code Style
- **Ruby Style Guide**: Rails Omakase Ruby styling (rubocop-rails-omakase)
- **Auto-fix command**: `bin/rubocop -a`
- **Configuration**: `.rubocop.yml`
- **Naming**: Use descriptive names, follow Rails conventions
- **Comments**: Only add where logic isn't self-evident, avoid over-commenting

### Architecture Patterns

**Service Objects:**
- Business logic extracted into service objects (`app/services/`)
- Key services: `AvailabilityService`, `SlotGenerator`, `OverlapChecker`
- Services are pure Ruby classes, tested independently

**Model Concerns:**
- Reusable model behaviors in `app/models/concerns/`
- Example: `TemporalScopes` for datetime queries

**Custom Validators:**
- Reusable validators in `app/validators/`
- Example: `TimeRangeValidator` for time range validation

**Implicit Authorization:**
- No explicit roles column
- User capabilities determined by associations (offices.exists?, appointments.exists?)
- Office-level permissions via `office_memberships.role` (owner, admin, member)
- Access control via association scoping, not role checks

**Database Patterns:**
- UUID primary keys for all tables
- Soft-delete with `is_active` boolean flags
- JSONB for complex data (work_periods) with GIN indexes
- Composite indexes for performance (customer_id, scheduled_at)

### Testing Strategy

**Framework**: Rails Minitest with parallel execution

**Test Organization:**
- `test/models/` - Unit tests for Active Record models
- `test/models/concerns/` - Tests for model concerns
- `test/services/` - Unit tests for service objects
- `test/system/` - End-to-end browser tests (Capybara + Selenium)
- `test/fixtures/` - YAML fixture data

**Testing Principles:**
- Fixture-driven tests
- Service objects isolated and tested independently
- Comprehensive validation coverage including edge cases
- Test single files: `bin/rails test test/models/user_test.rb`
- Test specific line: `bin/rails test test/models/user_test.rb:12`

**CI Pipeline** (`bin/ci`):
1. Setup (bin/setup --skip-server)
2. Ruby style check (bin/rubocop)
3. Security: Gem audit (bin/bundler-audit)
4. Security: Importmap audit (bin/importmap audit)
5. Security: Brakeman analysis (bin/brakeman)
6. Tests: Rails (bin/rails test)
7. Tests: System (bin/rails test:system)
8. Tests: Seeds (test db:seed:replant)

### Git Workflow
- **Main branch**: `main`
- **Commit style**: Descriptive, imperative mood (e.g., "Add user authentication")
- **Before committing**: Run `bin/ci` to ensure all checks pass
- **PR target**: `main` branch

## Domain Context

### Core Business Logic: Availability Calculation Engine

The availability calculation is the heart of the system, using a **3-layer architecture**:

1. **WorkSchedule (Foundation)**: Defines when a provider works
   - Day-based (0-6 = Sunday-Saturday)
   - Stores `work_periods` as JSON array allowing breaks
   - Example: `[{"start"=>"09:00","end"=>"12:00"},{"start"=>"13:00","end"=>"17:00"}]`
   - Defines appointment duration and buffer times

2. **AvailabilityService (Calculation)**: Subtracts booked appointments from work periods
   - Core algorithm: `subtract_time_range()` handles 5 overlap cases
   - Cases: no overlap, complete overlap, overlaps start, overlaps end, middle overlap (splits period)
   - Located: `app/services/availability_service.rb`

3. **SlotGenerator (Discretization)**: Converts availability into fixed-size appointment slots
   - Uses `AvailableSlot` value object with status ("available"/"busy")
   - Respects buffer time between appointments
   - Located: `app/services/slot_generator.rb`

**Supporting Services:**
- `OverlapChecker`: Centralized interval overlap detection logic

### Domain Entities

**Users** (Dual-Role System):
- Can be provider, customer, or both simultaneously
- Provider capability: `current_user.offices.exists?`
- Customer capability: `current_user.appointments.exists?`
- CPF (Brazilian ID) optional but unique when provided

**Offices**:
- Physical/virtual locations where services are provided
- Geocoding support for location
- Timezone-aware scheduling (ActiveSupport::TimeZone)
- Multi-provider management

**WorkSchedules**:
- Provider availability templates per office per day
- Support for complex work periods (lunch breaks, multiple shifts)
- Active-based versioning (only one active schedule per provider per day per office)

**Appointments**:
- Status tracking: pending, confirmed, cancelled, completed
- Duration stored in `duration_minutes` (default: 50 minutes)
- End time calculated: scheduled_at + duration + buffer
- Status transitions: pending → confirmed → completed (or cancelled from any state)

**OfficeMemberships**:
- Join table: users ↔ offices
- Role-based permissions: owner, admin, member

**AvailabilityCalendars**:
- Pre-computed cache of available/busy periods for performance

### Brazilian Context
- **CPF**: Brazilian taxpayer ID (normalized to digits-only)
- **Language**: Portuguese (BR) for user-facing content
- **Timezone**: Multiple timezone support for offices across Brazil

## Important Constraints

### Business Rules
1. **No Recurring Appointments**: Each booking is discrete (no repeat patterns)
2. **Office is Required**: All appointments must be tied to an office
3. **Work Period Validation**: Appointment duration must fit within work day, no overlapping work periods
4. **Active Schedule Uniqueness**: Only one active schedule per provider per day per office
5. **Status Transitions**: Appointments follow lifecycle (pending → confirmed → completed or cancelled)
6. **Single Provider per Appointment**: Appointments have one provider, not multiple

### Technical Constraints
- **UUID Primary Keys**: All tables use PostgreSQL `gen_random_uuid()`
- **Timezone-Aware**: All datetime handling must respect office timezone
- **Soft-Delete**: Use `is_active` flags, never hard delete offices/memberships/schedules
- **String Enums**: Use string-based enums, not integers
- **Authentication Required**: All controllers use `before_action :authenticate_user!`

### Performance Considerations
- **Composite Indexes**: Critical queries have multi-column indexes
- **JSON Indexing**: JSONB fields have GIN indexes
- **Availability Cache**: Pre-computed via AvailabilityCalendars
- **Parallel Tests**: Enabled for faster test execution

## External Dependencies

### Key Services
- **Geocoder**: Office location geocoding
- **Devise**: User authentication system
- **PostgreSQL**: Primary database (requires UUID support)

### Development Dependencies
- **Foreman**: Process manager (bin/dev runs Rails + Tailwind)
- **Selenium WebDriver**: System testing browser automation
- **Brakeman**: Security vulnerability scanning
- **RuboCop**: Code style enforcement

## Important Entry Points

### Core Models
- `app/models/user.rb` - User authentication and dual-role logic
- `app/models/office.rb` - Office management with geocoding
- `app/models/appointment.rb` - Appointment bookings with status tracking
- `app/models/work_schedule.rb` - Provider availability templates

### Business Logic Services
- `app/services/availability_service.rb` - Availability calculation engine
- `app/services/slot_generator.rb` - Slot discretization
- `app/services/overlap_checker.rb` - Interval overlap detection

### Authentication & Authorization
- `app/controllers/application_controller.rb` - Devise integration, permitted parameters

### Reusable Components
- `app/models/concerns/temporal_scopes.rb` - Datetime query scopes
- `app/validators/time_range_validator.rb` - Time range validation

## Development Commands

### Setup & Running
```bash
bin/setup                    # Initial setup
bin/dev                      # Start Rails + Tailwind (recommended)
bin/rails server             # Rails only
```

### Testing
```bash
bin/rails test              # Run all tests
bin/rails test:system       # System tests
bin/ci                      # Full CI suite
```

### Code Quality
```bash
bin/rubocop                 # Style check
bin/rubocop -a              # Auto-fix
bin/brakeman                # Security scan
```

### Database
```bash
bin/rails db:prepare        # Create/migrate
bin/rails db:reset          # Drop/create/migrate/seed
```

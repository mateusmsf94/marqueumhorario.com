# Design Document: Appointment Confirmation Workflow

## Context

The Marque Um Horário appointment scheduling system currently allows customers to book appointments, which are created with `pending` status. The provider dashboard displays these pending appointments but lacks functional confirmation controls. This design document outlines the technical decisions for implementing the complete confirmation workflow.

**Existing Infrastructure:**
- Appointment model with status enum (pending, confirmed, cancelled, completed)
- Provider dashboard with disabled confirm/decline buttons
- Customer booking flow creating pending appointments
- Optimistic locking via `lock_version` column
- Association scoping for authorization (`current_user.provider_appointments`)

**Stakeholders:**
- Providers: Need to manage incoming appointment requests
- Customers: Need ability to cancel their bookings
- System: Must maintain data integrity and audit trail

## Goals / Non-Goals

**Goals:**
- Enable providers to confirm or decline pending appointments
- Require decline reason for transparency and communication
- Allow customers to cancel non-completed appointments
- Maintain audit trail with timestamps (confirmed_at, declined_at)
- Stub notification infrastructure for future email sending
- Prevent unauthorized access and race conditions

**Non-Goals:**
- Implementing actual email notifications (infrastructure only, no sending)
- Adding state machine gem (simple enum sufficient)
- Implementing cancellation time windows (can add later)
- Bulk confirmation actions (single appointment at a time)
- Automatic appointment expiration (manual management only)

## Decisions

### 1. Service Object vs Controller Logic

**Decision:** Keep confirmation logic in controller (no service object initially)

**Rationale:**
- Confirmation/decline/cancel are simple status transitions with minimal business logic
- Current codebase pattern: Service objects used for complex calculations (AvailabilityService, SlotGenerator) or multi-step processes
- Status transitions with timestamp updates can be handled cleanly in controller with model callbacks
- YAGNI principle - add service object only if complexity increases

**When to refactor:**
- If confirmation requires availability recalculation or conflict detection
- If cancellation triggers cascade operations (refunds, rescheduling)
- If business rules become complex (cancellation windows, partial confirmations)

**Alternatives considered:**
- Service object approach: `AppointmentConfirmationService.confirm(appointment, provider)`
  - Pro: Encapsulates business logic, easier to test in isolation
  - Con: Adds unnecessary layer for simple status transitions
  - Con: Would need multiple service classes (ConfirmService, DeclineService, CancelService)

### 2. Decline Reason Validation

**Decision:** Model-level validation with conditional logic

**Rationale:**
- Data integrity: decline_reason should ONLY be present when status is cancelled AND initiated by provider
- Model is single source of truth for validation
- Prevents invalid data even if controller validation is bypassed
- Custom validation method provides clear error messages

**Implementation:**
```ruby
validate :decline_reason_required_when_declined, if: :will_save_change_to_status?

def decline_reason_required_when_declined
  if status == "cancelled" && declined_at.present? && decline_reason.blank?
    errors.add(:decline_reason, "is required when declining an appointment")
  end
end
```

**Defense in depth:**
- Model validation (primary)
- Controller validation (secondary - fails fast)
- Frontend validation (tertiary - HTML5 required + JavaScript)

**Alternatives considered:**
- Controller-only validation
  - Pro: Faster feedback to user
  - Con: Can be bypassed, data integrity risk
- Database constraint
  - Pro: Ultimate data integrity
  - Con: Cannot express conditional logic in PostgreSQL CHECK constraint (requires trigger)

### 3. Timestamp Management

**Decision:** Model callbacks for automatic timestamp setting

**Rationale:**
- Ensures timestamps are always set correctly and consistently
- Prevents manual timestamp errors (forgetting to set, setting wrong time)
- Audit trail integrity
- DRY principle - single place to manage timestamps
- Callbacks run during transaction, ensuring atomicity

**Implementation:**
```ruby
before_save :set_confirmation_timestamp

def set_confirmation_timestamp
  if will_save_change_to_status? && status == "confirmed"
    self.confirmed_at = Time.current unless confirmed_at_changed?
  end
end
```

**Note:** `declined_at` is set explicitly in controller (not callback) to distinguish provider decline from customer cancel.

**Alternatives considered:**
- Controller sets timestamps
  - Pro: More explicit, easier to trace
  - Con: Duplicated logic across multiple actions
  - Con: Easy to forget in new actions
- Database trigger
  - Pro: Absolute guarantee
  - Con: Logic hidden from application code
  - Con: Harder to test and maintain

### 4. Concurrent Confirmations (Optimistic Locking)

**Decision:** Use existing `lock_version` column (already in schema)

**Current state:**
- Database already has `lock_version` column (integer, default: 0, not null)
- Rails optimistic locking is automatic when lock_version present
- No additional code or configuration needed

**How it works:**
1. User loads appointment (lock_version: 0)
2. User modifies appointment
3. Rails includes WHERE lock_version = 0 in UPDATE
4. If another user modified same appointment (lock_version now 1), UPDATE affects 0 rows
5. `ActiveRecord::StaleObjectError` raised
6. Controller rescues exception and shows user-friendly error message

**Controller pattern:**
```ruby
def confirm
  @appointment.confirmed!
  redirect_to providers_dashboard_path, notice: "Appointment confirmed successfully"
rescue ActiveRecord::StaleObjectError
  redirect_to providers_dashboard_path, alert: "Appointment was modified by another user. Please try again."
end
```

**Alternatives considered:**
- Pessimistic locking (`lock!`)
  - Pro: Prevents concurrent modifications entirely
  - Con: Locks database row, blocks other operations
  - Con: Requires managing lock release
  - Con: Overkill for this use case (confirmations are rare, conflicts unlikely)
- No locking
  - Pro: Simplest approach
  - Con: Last write wins, potential data loss
  - Con: No conflict detection

### 5. Customer Cancellation Business Rule

**Decision:** Allow customers to cancel ANY status except completed

**Rationale:**
- Customer should always have control over their appointments
- Pending appointments: Customer changed mind before provider reviewed
- Confirmed appointments: Customer can no longer make it, provider should know
- Completed appointments: Historical record, should not be modified

**Status transition rules:**
- Provider confirm: pending → confirmed (sets confirmed_at)
- Provider decline: pending → cancelled (sets declined_at + decline_reason)
- Provider cancel: any → cancelled (for emergencies, sets declined_at + decline_reason)
- Customer cancel: pending/confirmed → cancelled (no declined_at, no decline_reason)

**Edge case handling:**
```ruby
def cancel
  if @appointment.completed?
    redirect_to customers_appointments_path, alert: "Cannot cancel completed appointment"
    return
  end

  @appointment.cancelled!
  # declined_at and decline_reason remain nil
  redirect_to customers_appointments_path, notice: "Appointment cancelled successfully"
end
```

**Alternatives considered:**
- Only allow cancelling pending appointments
  - Pro: Prevents customer from cancelling after provider confirmed
  - Con: Real-world: customers need flexibility (emergencies, schedule changes)
  - Con: Poor user experience
- Add cancellation time window (e.g., can't cancel <24h before)
  - Pro: Protects provider revenue/time
  - Con: Requires additional business logic and configuration
  - **Future enhancement:** Can add later with validation

### 6. Authorization Pattern

**Decision:** Association scoping (existing pattern in codebase)

**Current pattern:**
```ruby
# Provider authorization
current_user.provider_appointments.find(params[:id])  # Raises ActiveRecord::RecordNotFound if not provider's appointment

# Customer authorization
current_user.appointments.find(params[:id])  # Raises ActiveRecord::RecordNotFound if not customer's appointment
```

**Benefits:**
- Implicit authorization (no explicit role checks)
- Leverages existing Rails associations
- Consistent with codebase patterns
- SQL-level filtering (secure)
- Automatic 404 error on unauthorized access

**No Pundit/CanCanCan needed** - association scoping provides sufficient authorization for this use case.

**Controller implementation:**
```ruby
private

def set_appointment
  @appointment = current_user.provider_appointments.find(params[:id])
end
```

If appointment doesn't belong to current_user, `ActiveRecord::RecordNotFound` is raised and Rails returns 404.

**Alternatives considered:**
- Pundit policy
  - Pro: Explicit authorization logic, easier to audit
  - Con: Adds gem dependency
  - Con: Overkill for simple association-based authorization
- CanCanCan abilities
  - Pro: Centralized authorization rules
  - Con: Adds complexity for simple use case
- Manual authorization check
  - Pro: Explicit
  - Con: Easy to forget, inconsistent with codebase pattern

### 7. Notification Infrastructure

**Decision:** Create mailer structure, stub methods, NO email sending

**Rationale:**
- User requirement: "Add notification infrastructure but don't send emails yet"
- Prepare for future email sending without implementing now
- Stub methods with TODO comments for tracking
- Separates infrastructure from implementation (can add email sending later)

**Implementation:**
```ruby
class AppointmentMailer < ApplicationMailer
  default from: "notifications@marqueumhorario.com"

  def confirmed(appointment)
    # TODO: Implement email sending when ready
    # @appointment = appointment
    # @customer = appointment.customer
    # mail(to: @customer.email, subject: "Appointment Confirmed")
  end

  def declined(appointment)
    # TODO: Implement email sending with decline_reason
  end

  def cancelled_by_customer(appointment)
    # TODO: Notify provider when customer cancels
  end
end
```

**Future implementation:**
- Controllers will call: `AppointmentMailer.confirmed(@appointment).deliver_later`
- Use `deliver_later` (solid_queue already in stack) - async, doesn't block user action
- Separate action success from email delivery (email failures don't fail confirmation)

**Alternatives considered:**
- Implement email sending now
  - Con: User explicitly requested stub only
  - Con: Requires email configuration (SMTP, templates, testing)
- Skip mailer entirely
  - Con: Would need to create later, more work overall
  - Con: No clear marker for future implementation

### 8. State Machine Consideration

**Decision:** NO state machine gem (AASM, Statesman, etc.)

**Rationale:**
- Current implementation uses Rails enums with bang methods (`.confirmed!`, `.cancelled!`)
- Simple status transitions (4 states: pending, confirmed, cancelled, completed)
- No complex state guards or conditional transitions (yet)
- No need for transition callbacks with complex logic
- Rails enums + validations + model callbacks are sufficient

**When to add state machine:**
- Complex transition rules (e.g., "can only cancel if >24h before appointment")
- Multiple intermediate states (e.g., pending → reviewing → approved → confirmed)
- Need for transition history/audit trail beyond timestamps
- Conditional transitions based on external factors

**Current approach:**
```ruby
# Simple enum with validation
enum status: { pending: "pending", confirmed: "confirmed", cancelled: "cancelled", completed: "completed" }

# Manual status checks
if @appointment.cancelled?
  # handle already cancelled
end

@appointment.confirmed!  # Built-in bang method
```

**Alternatives considered:**
- AASM (Acts As State Machine)
  - Pro: Explicit transition definitions, guards, callbacks
  - Con: Adds gem dependency
  - Con: Overkill for 4-state system with simple rules
- Statesman
  - Pro: Stores transition history in separate table
  - Con: More complex setup
  - Con: Not needed yet (timestamps provide sufficient audit trail)

## Risks / Trade-offs

### Risk 1: Race Conditions (Double Confirmation)

**Scenario:** Two providers attempt to confirm same appointment simultaneously

**Impact:** Medium - Could lead to confusion, but no data corruption

**Mitigation:**
- ✅ Already mitigated: `lock_version` column enables optimistic locking
- Controller rescues `ActiveRecord::StaleObjectError`
- Shows user-friendly error message: "Appointment was modified by another user. Please try again."
- User retries action with refreshed data

**Test coverage:**
- System test: Simulate concurrent updates
- Controller test: Verify StaleObjectError handling

### Risk 2: Customer Cancels During Provider Confirmation

**Scenario:** Customer cancels appointment while provider is viewing confirmation page and clicking confirm

**Impact:** Low - Provider sees stale data, attempts confirmation on cancelled appointment

**Mitigation:**
- Status validation: Cannot confirm cancelled appointment
- Controller checks current status before confirming:
  ```ruby
  if @appointment.cancelled?
    redirect_to providers_dashboard_path, alert: "Cannot confirm cancelled appointment"
    return
  end
  ```
- Show error message to provider
- Provider sees updated list on dashboard refresh

**Trade-off:** Slightly worse UX (provider sees error) vs data integrity (no confirming cancelled appointments)

### Risk 3: Missing Decline Reason

**Scenario:** Provider submits decline without reason (client-side validation bypassed or disabled JavaScript)

**Impact:** High - Data integrity issue, customer doesn't know why appointment was declined

**Mitigation (defense in depth):**
1. **Frontend validation:** HTML5 `required` attribute + JavaScript validation
2. **Controller validation:** Check presence before attempting decline
   ```ruby
   if params[:decline_reason].blank?
     redirect_to providers_dashboard_path, alert: "Please provide a reason for declining"
     return
   end
   ```
3. **Model validation:** `decline_reason` required when `declined_at.present?`
   ```ruby
   validate :decline_reason_required_when_declined
   ```

**Test coverage:**
- Model test: Verify validation error when decline_reason missing
- Controller test: Verify error handling and status unchanged
- System test: Attempt to submit empty form, verify error message

### Risk 4: Timestamp Integrity

**Scenario:** Manual timestamp manipulation, callback failures, or incorrect timestamp setting

**Impact:** Medium - Audit trail corruption, confusion about when confirmations occurred

**Mitigation:**
- Model callbacks set timestamps automatically (not manual in controller)
- Timestamps are NOT exposed in strong parameters (cannot be manipulated via forms)
- Database constraints: `confirmed_at`, `declined_at` are nullable (allow existing records)
- `unless confirmed_at_changed?` check prevents overwriting manually-set timestamps (edge case)

**Test coverage:**
- Model test: Verify confirmed_at is set when status changes to confirmed
- Model test: Verify confirmed_at is NOT changed if already set
- Model test: Verify declined_at is set by controller, not callback

### Risk 5: N+1 Queries on Dashboard

**Scenario:** Loading pending appointments with associations causes N+1 queries (performance degradation)

**Impact:** Medium - Slow page loads as pending appointments grow

**Current state:**
```ruby
@pending_appointments = current_user.provider_appointments
  .by_status(:pending)
  .upcoming
  .includes(:customer, :office)  # ✅ Already optimized
```

**Mitigation:**
- ✅ Already mitigated: `.includes(:customer, :office)` eager loads associations
- Prevents N+1 by loading all customers and offices in 3 queries (appointments, customers, offices)
- Monitor with Bullet gem (recommended to add to development environment)

**Trade-off:** Slightly more memory usage (loading associations) vs much faster rendering

### Risk 6: Email Sending in Future

**Scenario:** When emails are implemented, sending failures could block confirmation actions

**Impact:** Medium - User action fails due to email service outage (poor UX)

**Mitigation (for future implementation):**
- Use background jobs (`solid_queue` already in stack)
- Separate action success from email delivery
- Pattern:
  ```ruby
  @appointment.confirmed!
  AppointmentMailer.confirmed(@appointment).deliver_later  # Async, doesn't block
  redirect_to providers_dashboard_path, notice: "Appointment confirmed successfully"
  ```
- Email failures don't affect confirmation (appointment is confirmed regardless)
- Log email failures for monitoring

**Trade-off:** Customer might not receive immediate notification vs reliable confirmation action

## Migration Plan

### Phase 1: Database Migration

```ruby
class AddConfirmationFieldsToAppointments < ActiveRecord::Migration[8.1]
  def change
    add_column :appointments, :confirmed_at, :datetime
    add_column :appointments, :declined_at, :datetime
    add_column :appointments, :decline_reason, :text

    add_index :appointments, :confirmed_at
    add_index :appointments, :declined_at
  end
end
```

**Rollback strategy:**
- Migration is reversible (columns can be removed)
- No data loss - timestamps are additive (nullable columns)
- Existing appointments unaffected (confirmed_at/declined_at will be nil)
- Safe to rollback if issues discovered

**Deployment:**
- Zero-downtime: Adding nullable columns doesn't lock table (PostgreSQL)
- Indexes created with `CONCURRENT` (implicit in Rails migrations)
- No backfill needed (new appointments will populate timestamps going forward)

### Phase 2: Implementation Sequence

**Order of implementation (to minimize risk):**

1. **Model updates** (validations, callbacks)
   - Lowest risk: Pure Ruby code, easily tested
   - Existing appointments unaffected (nullable columns)

2. **Routes** (add endpoints)
   - Low risk: Additive only, no breaking changes
   - Existing routes unchanged

3. **Controllers** (confirm, decline, cancel actions)
   - Medium risk: New code paths, authorization critical
   - Comprehensive test coverage required

4. **Views** (enable buttons, add modal)
   - Low risk: UI changes only
   - Can feature-flag if needed

5. **Mailer stubs** (infrastructure)
   - Lowest risk: No-op methods, no email sending

6. **Tests** (model, controller, system)
   - Critical: Must pass before deployment

**Integration testing:**
- Manual testing in development environment after each phase
- Full CI suite must pass before deployment
- Staging environment testing before production

## Open Questions

### Q1: Should confirmed appointments be cancellable by provider?

**Current decision:** Yes, provider can cancel any non-completed appointment (for emergencies)

**Rationale:**
- Real-world scenarios: provider gets sick, office closes unexpectedly
- Flexibility is important for provider operations
- Same decline_reason requirement applies (transparency to customer)

**Alternative:** Only allow cancellation of pending appointments
- Pro: Prevents provider from cancelling after confirmation (commitment)
- Con: No flexibility for genuine emergencies
- Con: Provider would need to contact customer directly (poor UX)

**Resolution:** Allow provider cancellation with same decline_reason requirement. Monitor if this is abused (can add constraints later if needed).

### Q2: Should customer see decline_reason?

**Current decision:** Yes, display decline_reason in appointment detail view

**Rationale:**
- Transparency - customer deserves to know why appointment was declined
- Communication - reduces support requests ("Why was my appointment rejected?")
- Professionalism - providers should write clear, respectful reasons

**Privacy consideration:**
- Providers should be aware decline_reason is visible to customer
- Add helper text in decline modal: "This reason will be visible to the customer"

**Implementation:**
```erb
<% if @appointment.declined_by_provider? %>
  <div class="bg-yellow-50 border-l-4 border-yellow-400 p-4">
    <p class="font-semibold">Appointment Declined</p>
    <p class="text-sm text-gray-700"><%= @appointment.decline_reason %></p>
  </div>
<% end %>
```

**Alternative:** Hide decline_reason from customer
- Con: Poor transparency, customer won't know why
- Con: More support requests

### Q3: Time window for cancellation?

**Current decision:** No time restriction (can cancel anytime before completed)

**Rationale:**
- Simplicity - easier to implement and understand
- Flexibility - allows cancellations up to appointment time
- Can add restrictions later if business requires

**Alternative:** Add cancellation window (e.g., "cannot cancel <24h before appointment")
- Pro: Protects provider revenue (late cancellations costly)
- Pro: Encourages customers to cancel earlier
- Con: Requires additional business logic
- Con: Requires configuration UI (what should window be?)
- Con: May frustrate customers (genuine emergencies)

**Resolution:** Implement later if business requires. Would add validation in Appointment model:
```ruby
validate :cannot_cancel_within_24_hours, if: :cancelling_by_customer?

def cannot_cancel_within_24_hours
  if scheduled_at < 24.hours.from_now
    errors.add(:base, "Cannot cancel appointments less than 24 hours in advance")
  end
end
```

### Q4: Should declined appointments show in provider dashboard?

**Current decision:** No dedicated "declined" section initially

**Rationale:**
- Pending appointments are priority (need action)
- Declined appointments are historical (already resolved)
- Declined appointments appear in general "past appointments" list (filtered by status if needed)
- Keeps dashboard focused on actionable items

**Alternative:** Add "Declined Appointments" section to dashboard
- Pro: Visibility into rejection rate
- Pro: Providers can review their decline reasons
- Con: Adds clutter to dashboard
- Con: Not immediately actionable

**Resolution:** Add status filter to appointments index later if providers request it:
```ruby
# Future enhancement
@declined_appointments = current_user.provider_appointments
  .by_status(:cancelled)
  .where.not(declined_at: nil)
  .order(declined_at: :desc)
  .limit(10)
```

## Dependencies

### Internal Dependencies

- ✅ Appointment model with status enum (exists in `app/models/appointment.rb`)
- ✅ Devise authentication (exists, provides `current_user`)
- ✅ Association scoping (exists: `current_user.provider_appointments`, `current_user.appointments`)
- ✅ Optimistic locking (exists: `lock_version` column in appointments table)
- ✅ TemporalScopes concern (exists: `.upcoming`, `.past` scopes)

### External Dependencies

- ✅ Rails 8.1.1 (current version, supports all features needed)
- ✅ PostgreSQL with UUID support (current database)
- ✅ Turbo/Hotwire (current stack, for modal interactions and form submissions)
- ⚪ Solid Queue (current stack, for future email sending via `deliver_later`)

### Test Dependencies

- ✅ Minitest with fixtures (current test framework)
- ✅ Capybara + Selenium (current system test setup)
- ✅ Devise test helpers (provides `sign_in` support in tests)

All dependencies are already in the project - no new gems required.

## Summary

This design document outlines a pragmatic approach to implementing appointment confirmation:

- **Simple is better:** Use Rails conventions (enums, callbacks, associations) instead of adding gems
- **Data integrity:** Model validations + controller checks + frontend validation (defense in depth)
- **Security:** Association scoping for authorization, optimistic locking for concurrency
- **Audit trail:** Timestamps track confirmation/decline events
- **Future-ready:** Notification infrastructure stubbed for later implementation
- **Low risk:** Additive changes only, comprehensive test coverage, reversible migration

Key trade-offs:
- Simplicity (no state machine) vs future flexibility (might need one later)
- Customer flexibility (can cancel anytime) vs provider protection (no cancellation window)
- Transparency (show decline_reason) vs privacy (could hide it)

All decisions are reversible and can be refined based on real-world usage and feedback.
# Change: Add Appointment Confirmation Workflow

## Why

Currently, when customers book appointments through the public booking system, appointments are created with `pending` status. The provider dashboard displays these pending appointments with disabled "Confirm" and "Decline" buttons showing "(Actions coming soon)" text. Providers have no way to approve or reject appointments, and customers cannot cancel their bookings.

This creates several problems:
- Providers cannot manage their schedule by accepting/rejecting appointments
- Customers are locked into appointments with no self-service cancellation
- No audit trail exists for when confirmations occur
- The booking workflow is incomplete and non-functional

## What Changes

This change implements the complete appointment confirmation workflow:

**Provider Capabilities:**
- Confirm pending appointments (changes status to `confirmed`, sets `confirmed_at` timestamp)
- Decline pending appointments with **required** reason text (changes status to `cancelled`, sets `declined_at` timestamp and `decline_reason`)
- Cancel any appointment (for emergency situations)
- Authorization: providers can only modify their own appointments

**Customer Capabilities:**
- Cancel their own appointments (pending or confirmed, but not completed)
- View decline reason when provider declines their appointment
- Authorization: customers can only cancel their own appointments

**Database Schema:**
- Add `confirmed_at` (datetime, nullable) - tracks when appointment was confirmed
- Add `declined_at` (datetime, nullable) - tracks when appointment was declined by provider
- Add `decline_reason` (text, nullable) - stores provider's reason for declining
- Add indexes on `confirmed_at` and `declined_at` for query performance

**UI Enhancements:**
- Enable confirm/decline buttons in provider dashboard (currently disabled)
- Add decline reason modal for text input when declining
- Add cancel button to customer appointments page
- Add flash messages for success/error feedback

**Notification Infrastructure:**
- Create `AppointmentMailer` with stubbed methods (confirmed, declined, cancelled_by_customer)
- Do NOT send actual emails yet (infrastructure for future implementation)
- Add TODO comments for future email sending

## Impact

**Affected Specs:**
- `appointment-management` (new capability) - Provider confirmation/decline workflow
- `customer-booking` (existing capability) - Add customer cancellation

**Affected Code:**
- **New files (9):**
  - `db/migrate/*_add_confirmation_fields_to_appointments.rb`
  - `app/controllers/providers/appointments_controller.rb`
  - `app/mailers/appointment_mailer.rb`
  - `app/views/appointment_mailer/{confirmed,declined,cancelled_by_customer}.html.erb` (3 files)
  - `test/controllers/providers/appointments_controller_test.rb`
  - `test/mailers/appointment_mailer_test.rb`
  - `test/system/appointment_confirmation_test.rb`

- **Modified files (6):**
  - `config/routes.rb` - Add appointment management routes
  - `app/models/appointment.rb` - Add validations, callbacks, helper methods
  - `app/controllers/customers/appointments_controller.rb` - Add cancel action
  - `app/views/providers/dashboard/index.html.erb` - Enable buttons, add modal
  - `app/views/customers/appointments/index.html.erb` - Add cancel button
  - `test/models/appointment_test.rb` - Add validation tests

**Breaking Changes:**
- None - this is purely additive functionality

**Risk Mitigation:**
- Existing `lock_version` column provides optimistic locking for concurrent updates
- Association scoping prevents unauthorized access (implicit authorization)
- Model validations ensure data integrity (decline_reason required when declined)
- Comprehensive test coverage (model, controller, system tests)

**Performance Impact:**
- Minimal - adds 2 simple indexes, no complex queries
- Dashboard already uses `.includes(:customer, :office)` to prevent N+1 queries

# Implementation Tasks

## 1. Database Schema

- [x] 1.1 Create migration to add confirmation fields to appointments table
  - [x] Add `confirmed_at` column (datetime, nullable)
  - [x] Add `declined_at` column (datetime, nullable)
  - [x] Add `decline_reason` column (text, nullable)
  - [x] Add index on `confirmed_at`
  - [x] Add index on `declined_at`
- [x] 1.2 Run migration (`bin/rails db:migrate`)
- [x] 1.3 Verify schema changes in `db/schema.rb`

## 2. Model Updates

- [x] 2.1 Add validation for decline_reason in `app/models/appointment.rb`
  - [x] Create `decline_reason_required_when_declined` validation method
  - [x] Validate decline_reason presence when status is cancelled AND declined_at is present
- [x] 2.2 Add callback for automatic timestamp setting
  - [x] Create `set_confirmation_timestamp` before_save callback
  - [x] Set `confirmed_at` when status changes to confirmed
- [x] 2.3 Add helper methods (optional)
  - [x] `declined_by_provider?` - returns true if cancelled with declined_at present
  - [x] `cancelled_by_customer?` - returns true if cancelled without declined_at

## 3. Routes

- [x] 3.1 Add provider appointments routes in `config/routes.rb`
  - [x] Add `resources :appointments, only: []` in providers namespace
  - [x] Add member route `patch :confirm`
  - [x] Add member route `patch :decline`
  - [x] Add member route `patch :cancel`
- [x] 3.2 Add customer cancel route
  - [x] Add member route `patch :cancel` to customers appointments

## 4. Controllers

- [x] 4.1 Create `app/controllers/providers/appointments_controller.rb`
  - [x] Add `before_action :authenticate_user!`
  - [x] Add `before_action :set_appointment` (uses association scoping)
  - [x] Implement `confirm` action
    - [x] Check if appointment is already cancelled
    - [x] Call `@appointment.confirmed!`
    - [x] Handle `ActiveRecord::StaleObjectError` for concurrent updates
    - [x] Redirect with success/error message
  - [x] Implement `decline` action
    - [x] Validate decline_reason parameter presence
    - [x] Set `declined_at` and `decline_reason`
    - [x] Call `@appointment.cancelled!`
    - [x] Handle validation errors
    - [x] Redirect with success/error message
  - [x] Implement `cancel` action
    - [x] Call `@appointment.cancelled!`
    - [x] Redirect with success message
  - [x] Implement private `set_appointment` method
    - [x] Use `current_user.provider_appointments.find(params[:id])` for authorization
- [x] 4.2 Update `app/controllers/customers/appointments_controller.rb`
  - [x] Add `cancel` action
    - [x] Find appointment via `current_user.appointments.find(params[:id])`
    - [x] Check if appointment is completed (reject if so)
    - [x] Call `@appointment.cancelled!`
    - [x] Redirect with success/error message

## 5. Views - Provider Dashboard

- [x] 5.1 Update `app/views/providers/dashboard/index.html.erb`
  - [x] Replace disabled confirm/decline buttons (lines 148-161)
  - [x] Wire confirm button to `confirm_providers_appointment_path(appointment)`
  - [x] Add Stimulus controller for decline modal
  - [x] Update button classes and remove "Actions coming soon" text
- [x] 5.2 Add decline reason modal to provider dashboard
  - [x] Create modal div with Stimulus modal controller
  - [x] Add form with decline_reason textarea (required)
  - [x] Wire form to decline action with appointment ID
  - [x] Add submit and cancel buttons
- [x] 5.3 Create Stimulus modal controller if needed
  - [x] `app/javascript/controllers/modal_controller.js`
  - [x] Implement `open` and `close` actions
  - [x] Handle modal visibility and form submission

## 6. Views - Customer Appointments

- [x] 6.1 Update `app/views/customers/appointments/index.html.erb`
  - [x] Add cancel button for each appointment
  - [x] Show button only for non-completed appointments
  - [x] Wire to `cancel_customers_appointment_path(appointment)`
  - [x] Add Turbo confirm dialog

## 7. Notification Infrastructure (Stub)

- [ ] 7.1 Create `app/mailers/appointment_mailer.rb`
  - [ ] Set default from email
  - [ ] Create `confirmed(appointment)` method with TODO comment
  - [ ] Create `declined(appointment)` method with TODO comment
  - [ ] Create `cancelled_by_customer(appointment)` method with TODO comment
- [ ] 7.2 Create mailer view stubs
  - [ ] `app/views/appointment_mailer/confirmed.html.erb`
  - [ ] `app/views/appointment_mailer/declined.html.erb`
  - [ ] `app/views/appointment_mailer/cancelled_by_customer.html.erb`

## 8. Tests - Models

- [ ] 8.1 Add tests to `test/models/appointment_test.rb`
  - [ ] Test decline_reason required when declined_at is present
  - [ ] Test confirmed_at set automatically when status changes to confirmed
  - [ ] Test decline_reason NOT required for customer cancellation (declined_at nil)
  - [ ] Test helper methods: `declined_by_provider?` and `cancelled_by_customer?`

## 9. Tests - Controllers

- [ ] 9.1 Create `test/controllers/providers/appointments_controller_test.rb`
  - [ ] Setup with provider user and pending appointment
  - [ ] Test confirm action success
    - [ ] Verify status changes to confirmed
    - [ ] Verify confirmed_at is set
    - [ ] Verify redirect and flash message
  - [ ] Test decline action with reason
    - [ ] Verify status changes to cancelled
    - [ ] Verify declined_at and decline_reason are set
    - [ ] Verify redirect and flash message
  - [ ] Test decline action without reason (failure)
    - [ ] Verify status remains unchanged
    - [ ] Verify error flash message
  - [ ] Test authorization (cannot confirm other provider's appointment)
    - [ ] Verify ActiveRecord::RecordNotFound raised
  - [ ] Test cannot confirm already cancelled appointment
  - [ ] Test concurrent update handling (StaleObjectError)
- [ ] 9.2 Update `test/controllers/customers/appointments_controller_test.rb`
  - [ ] Test cancel action success
    - [ ] Verify status changes to cancelled
    - [ ] Verify declined_at is nil (customer cancel, not provider decline)
    - [ ] Verify redirect and flash message
  - [ ] Test cannot cancel completed appointment
    - [ ] Verify status remains completed
    - [ ] Verify error flash message
  - [ ] Test authorization (cannot cancel other customer's appointment)

## 10. Tests - System

- [ ] 10.1 Create `test/system/appointment_confirmation_test.rb`
  - [ ] Test provider confirms pending appointment
    - [ ] Sign in as provider
    - [ ] Visit dashboard
    - [ ] Click confirm button
    - [ ] Verify success message
    - [ ] Verify appointment status changed
  - [ ] Test provider declines appointment with reason
    - [ ] Sign in as provider
    - [ ] Visit dashboard
    - [ ] Click decline button
    - [ ] Fill in decline reason in modal
    - [ ] Submit decline
    - [ ] Verify success message
    - [ ] Verify appointment status and decline_reason
  - [ ] Test customer cancels appointment
    - [ ] Sign in as customer
    - [ ] Visit appointments page
    - [ ] Click cancel button
    - [ ] Confirm in dialog
    - [ ] Verify success message
    - [ ] Verify appointment status changed

## 11. Quality Assurance

- [ ] 11.1 Run model tests (`bin/rails test test/models/appointment_test.rb`)
- [ ] 11.2 Run controller tests
  - [ ] `bin/rails test test/controllers/providers/appointments_controller_test.rb`
  - [ ] `bin/rails test test/controllers/customers/appointments_controller_test.rb`
- [ ] 11.3 Run system tests (`bin/rails test test/system/appointment_confirmation_test.rb`)
- [ ] 11.4 Run full test suite (`bin/rails test`)
- [ ] 11.5 Run system tests (`bin/rails test:system`)
- [ ] 11.6 Run RuboCop (`bin/rubocop`)
- [ ] 11.7 Run Brakeman security scan (`bin/brakeman`)
- [ ] 11.8 Run full CI suite (`bin/ci`)

## 12. Manual Testing

- [ ] 12.1 Test provider confirmation workflow
  - [ ] Book appointment as customer
  - [ ] Sign in as provider
  - [ ] Verify pending appointment appears
  - [ ] Confirm appointment
  - [ ] Verify status changed and timestamp set
- [ ] 12.2 Test provider decline workflow
  - [ ] Book appointment as customer
  - [ ] Sign in as provider
  - [ ] Click decline button
  - [ ] Verify modal opens
  - [ ] Submit without reason (verify validation error)
  - [ ] Submit with reason (verify success)
- [ ] 12.3 Test customer cancellation workflow
  - [ ] Sign in as customer
  - [ ] View appointments
  - [ ] Cancel pending appointment
  - [ ] Verify status changed
- [ ] 12.4 Test authorization
  - [ ] Attempt to confirm another provider's appointment (verify fails)
  - [ ] Attempt to cancel another customer's appointment (verify fails)
- [ ] 12.5 Test edge cases
  - [ ] Try to confirm already cancelled appointment
  - [ ] Try to cancel completed appointment
  - [ ] Test concurrent updates (open appointment in two browsers, confirm in both)

## 13. Documentation

- [ ] 13.1 Update CLAUDE.md if needed (document new confirmation workflow)
- [ ] 13.2 Add comments to complex logic (decline reason validation, timestamp callbacks)
- [ ] 13.3 Ensure mailer TODO comments are clear for future implementation

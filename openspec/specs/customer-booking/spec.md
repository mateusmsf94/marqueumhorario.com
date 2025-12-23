# customer-booking Specification

## Purpose
TBD - created by archiving change add-appointment-confirmation. Update Purpose after archive.
## Requirements
### Requirement: Customer Appointment Cancellation
Customers SHALL be able to cancel their own appointments that are not completed.

#### Scenario: Customer cancels pending appointment
- **WHEN** customer clicks "Cancel" on their pending appointment
- **THEN** appointment status changes to cancelled
- **AND** no decline_reason is required
- **AND** no declined_at timestamp is set
- **AND** success message confirms cancellation

#### Scenario: Customer cancels confirmed appointment
- **WHEN** customer cancels a confirmed appointment
- **THEN** appointment status changes to cancelled
- **AND** provider sees cancellation in their dashboard
- **AND** future: provider is notified via email

#### Scenario: Customer attempts to cancel completed appointment
- **WHEN** customer tries to cancel a completed appointment
- **THEN** error message is shown ("Cannot cancel completed appointment")
- **AND** appointment status remains completed

#### Scenario: Customer views cancellation button availability
- **WHEN** customer views their appointments list
- **THEN** cancel button is shown for pending and confirmed appointments
- **AND** cancel button is NOT shown for completed appointments
- **AND** cancel button is NOT shown for already cancelled appointments

### Requirement: Customer Authorization
Customers SHALL only be able to cancel their own appointments.

#### Scenario: Customer attempts to cancel another customer's appointment
- **WHEN** customer tries to access cancellation for appointment not belonging to them
- **THEN** authorization error occurs (404 Not Found)
- **AND** no status change is made

### Requirement: Decline Reason Visibility
Customers SHALL be able to see the reason when provider declines their appointment.

#### Scenario: Customer views declined appointment
- **WHEN** customer opens appointment details for declined appointment
- **THEN** decline reason provided by provider is displayed
- **AND** declined_at timestamp is shown

#### Scenario: Customer views self-cancelled appointment
- **WHEN** customer opens appointment details for self-cancelled appointment
- **THEN** no decline reason is shown (since customer initiated cancellation)
- **AND** status shows as "Cancelled" without provider reason


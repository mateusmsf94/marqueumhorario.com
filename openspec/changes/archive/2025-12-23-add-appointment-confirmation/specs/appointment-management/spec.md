## ADDED Requirements

### Requirement: Provider Appointment Confirmation
Providers SHALL be able to confirm pending appointments assigned to them.

#### Scenario: Provider confirms appointment
- **WHEN** provider clicks "Confirm" on pending appointment
- **THEN** appointment status changes to confirmed
- **AND** confirmed_at timestamp is set to current time
- **AND** customer sees confirmed status in their appointments list

#### Scenario: Provider attempts to confirm cancelled appointment
- **WHEN** provider tries to confirm an appointment that has been cancelled
- **THEN** error message is displayed
- **AND** appointment status remains cancelled

### Requirement: Provider Appointment Decline
Providers SHALL be able to decline pending appointments with a required reason.

#### Scenario: Provider declines with reason
- **WHEN** provider clicks "Decline" on pending appointment
- **AND** provides reason text in modal form
- **THEN** appointment status changes to cancelled
- **AND** declined_at timestamp is set to current time
- **AND** decline_reason is stored
- **AND** customer can see decline reason in appointment details

#### Scenario: Provider declines without reason
- **WHEN** provider attempts to decline without providing reason
- **THEN** validation error is shown
- **AND** appointment status remains unchanged
- **AND** declined_at and decline_reason remain null

### Requirement: Provider Appointment Cancellation
Providers SHALL be able to cancel any non-completed appointment for emergency situations.

#### Scenario: Provider cancels confirmed appointment
- **WHEN** provider cancels a confirmed appointment with reason
- **THEN** appointment status changes to cancelled
- **AND** declined_at timestamp is set
- **AND** decline_reason is stored
- **AND** customer can see cancellation reason

### Requirement: Provider Authorization
Providers SHALL only be able to confirm, decline, or cancel their own appointments.

#### Scenario: Provider attempts to confirm another provider's appointment
- **WHEN** provider tries to access confirmation action for appointment not assigned to them
- **THEN** authorization error occurs (404 Not Found)
- **AND** no status change is made

#### Scenario: Provider views only their pending appointments
- **WHEN** provider accesses dashboard
- **THEN** only appointments assigned to them are displayed
- **AND** pending appointments requiring confirmation are highlighted

### Requirement: Concurrent Update Handling
The system SHALL prevent data loss when multiple users modify the same appointment simultaneously.

#### Scenario: Concurrent confirmation attempts
- **WHEN** two providers attempt to confirm same appointment simultaneously
- **THEN** first confirmation succeeds
- **AND** second confirmation fails with clear error message
- **AND** user is instructed to retry with refreshed data

### Requirement: Audit Trail
The system SHALL maintain timestamps tracking when appointment confirmations and declines occur.

#### Scenario: Confirmation timestamp recorded
- **WHEN** appointment is confirmed
- **THEN** confirmed_at is set to current timestamp
- **AND** timestamp is preserved for historical record

#### Scenario: Decline timestamp recorded
- **WHEN** appointment is declined by provider
- **THEN** declined_at is set to current timestamp
- **AND** timestamp distinguishes provider decline from customer cancellation

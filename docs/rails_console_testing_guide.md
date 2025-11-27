# Rails Console Testing Guide - Appointment Booking Flow

This guide demonstrates the core appointment booking flow: provider setup → time slot generation → customer booking.

## Prerequisites

1. Ensure your database is migrated:
   ```bash
   rails db:migrate
   ```

2. Start Rails console:
   ```bash
   rails console
   ```

---

## Main Flow: Complete Booking Journey

### Step 1: Provider Signs Up

```ruby
# Provider creates their account
provider = User.create!(
  first_name: "Dr. João",
  last_name: "Silva",
  email: "joao.silva@example.com",
  password: "password123",
  password_confirmation: "password123",
  roles: ["provider"],
  cpf: "12345678901",
  phone: "11987654321"
)

# Verify
provider.provider?  # => true
puts "Provider created: #{provider.full_name}"
```

---

### Step 2: Provider Creates Office

```ruby
# Provider sets up their office/clinic
office = Office.create!(
  name: "Clínica Dr. Silva",
  time_zone: "America/Sao_Paulo",
  address: "Av. Paulista, 1000",
  city: "São Paulo",
  state: "SP",
  zip_code: "01310-100"
)

# Link provider to office as owner
OfficeMembership.create!(
  user: provider,
  office: office,
  role: :owner
)

# Verify
puts "Office created: #{office.name}"
puts "Provider manages #{provider.offices.count} office(s)"
```

---

### Step 3: Provider Sets Work Schedule

```ruby
# Define when provider is available (Monday, 9 AM - 6 PM)
# Lunch break: 12 PM - 1 PM
work_schedule = WorkSchedule.create!(
  provider: provider,
  office: office,
  day_of_week: 1,  # Monday (0=Sunday, 1=Monday, etc.)
  opening_time: "09:00",
  closing_time: "18:00",
  work_periods: [
    { "start" => "09:00", "end" => "12:00" },  # Morning shift
    { "start" => "13:00", "end" => "18:00" }   # Afternoon shift
  ],
  appointment_duration_minutes: 60,  # 1-hour appointments
  buffer_minutes_between_appointments: 15,  # 15-min buffer between appointments
  is_active: true
)

# Verify
puts "Work schedule created for #{Date::DAYNAMES[work_schedule.day_of_week]}"
puts "Hours: #{work_schedule.opening_time} - #{work_schedule.closing_time}"
puts "Appointment duration: #{work_schedule.appointment_duration_minutes} minutes"
puts "Work periods: #{work_schedule.work_periods}"
```

---

### Step 4: Generate Available Time Slots

```ruby
# Choose a date to generate slots (next Monday)
target_date = Date.today.next_occurring(:monday)

# Generate time slots using SlotGenerator
slots = SlotGenerator.new(
  office: office,
  provider: provider,
  start_date: target_date,
  end_date: target_date
).generate

# Display available slots
puts "\n=== Available Time Slots for #{target_date.strftime('%A, %B %d, %Y')} ==="
slots.each do |slot|
  if slot.status == "available"
    puts "✓ #{slot.start_time.strftime('%H:%M')} - #{slot.end_time.strftime('%H:%M')}"
  end
end

# Count slots
available_count = slots.count { |s| s.status == "available" }
puts "\nTotal available slots: #{available_count}"
```

**Expected output:**
```
Available slots from 9:00-12:00 (morning) and 13:00-18:00 (afternoon)
Each slot is 1 hour + 15 min buffer = 1 hour 15 minutes apart
Example: 09:00-10:00, 10:15-11:15, 13:00-14:00, 14:15-15:15, 15:30-16:30
```

---

### Step 5: Customer Signs Up

```ruby
# Customer creates their account
customer = User.create!(
  first_name: "Maria",
  last_name: "Santos",
  email: "maria.santos@example.com",
  password: "password123",
  password_confirmation: "password123",
  roles: ["customer"],
  phone: "11977654321"
)

# Verify
customer.customer?  # => true
puts "Customer created: #{customer.full_name}"
```

---

### Step 6: Customer Picks a Time Slot

```ruby
# Customer chooses first available slot
first_slot = slots.find { |s| s.status == "available" }

# Customer books the appointment
appointment = Appointment.create!(
  office: office,
  customer: customer,
  provider: provider,
  title: "Consulta Médica",
  scheduled_at: first_slot.start_time,
  status: :pending
)

puts "\n=== Appointment Booked ==="
puts "Customer: #{appointment.customer.full_name}"
puts "Provider: #{appointment.provider.full_name}"
puts "Office: #{appointment.office.name}"
puts "Date/Time: #{appointment.scheduled_at.strftime('%A, %B %d, %Y at %H:%M')}"
puts "Status: #{appointment.status}"
```

---

### Step 7: Provider Confirms Appointment

```ruby
# Provider reviews and confirms the booking
appointment.update!(status: :confirmed)

puts "✓ Appointment confirmed!"
```

---

## Verify the Complete Flow

### Check Provider's Appointments

```ruby
puts "\n=== Provider's Schedule ==="
provider.provider_appointments.upcoming.each do |apt|
  puts "#{apt.scheduled_at.strftime('%m/%d %H:%M')} - #{apt.customer.full_name} - #{apt.status}"
end
```

### Check Customer's Appointments

```ruby
puts "\n=== Customer's Bookings ==="
customer.appointments.upcoming.each do |apt|
  puts "#{apt.scheduled_at.strftime('%m/%d %H:%M')} - #{apt.provider.full_name} at #{apt.office.name}"
end
```

### Regenerate Slots (Now Shows Booked Slot as Busy)

```ruby
# Generate slots again for the same date
updated_slots = SlotGenerator.new(
  office: office,
  provider: provider,
  start_date: target_date,
  end_date: target_date
).generate

# Show availability after booking
puts "\n=== Updated Availability ==="
updated_slots.each do |slot|
  status_icon = slot.status == "available" ? "✓" : "✗"
  puts "#{status_icon} #{slot.start_time.strftime('%H:%M')} - #{slot.status}"
end
```

---

## Advanced: Multi-Day Schedule Setup

```ruby
# Set up work schedule for entire week
days_config = [
  { day: 1, name: "Monday" },    # Monday
  { day: 2, name: "Tuesday" },   # Tuesday
  { day: 3, name: "Wednesday" }, # Wednesday
  { day: 4, name: "Thursday" },  # Thursday
  { day: 5, name: "Friday" }     # Friday
]

days_config.each do |config|
  WorkSchedule.create!(
    provider: provider,
    office: office,
    day_of_week: config[:day],
    opening_time: "09:00",
    closing_time: "18:00",
    work_periods: [
      { "start" => "09:00", "end" => "12:00" },
      { "start" => "13:00", "end" => "18:00" }
    ],
    appointment_duration_minutes: 60,
    buffer_minutes_between_appointments: 15,
    is_active: true
  )
  puts "✓ #{config[:name]} schedule created"
end
```

### Generate Slots for Entire Week

```ruby
# Generate slots for next 7 days
start_date = Date.today
end_date = start_date + 7.days

weekly_slots = SlotGenerator.new(
  office: office,
  provider: provider,
  start_date: start_date,
  end_date: end_date
).generate

# Group by date
slots_by_date = weekly_slots.group_by { |slot| slot.start_time.to_date }

slots_by_date.each do |date, day_slots|
  available = day_slots.count { |s| s.status == "available" }
  puts "#{date.strftime('%A, %b %d')}: #{available} available slots"
end
```

---

## Cleanup

```ruby
# Remove test data
Appointment.destroy_all
WorkSchedule.destroy_all
OfficeMembership.destroy_all
Office.destroy_all
User.destroy_all

puts "✓ Test data cleaned up"
```

---

## Quick Reference

### Key Commands
```ruby
# Create provider
provider = User.create!(first_name: "...", roles: ["provider"], ...)

# Create office
office = Office.create!(name: "...", time_zone: "America/Sao_Paulo", ...)

# Link provider to office
OfficeMembership.create!(user: provider, office: office, role: :owner)

# Create work schedule
WorkSchedule.create!(provider: provider, office: office, day_of_week: 1, ...)

# Generate slots
SlotGenerator.new(office: office, provider: provider, start_date: date, end_date: date).generate

# Create customer
customer = User.create!(first_name: "...", roles: ["customer"], ...)

# Book appointment
Appointment.create!(office: office, customer: customer, provider: provider, scheduled_at: time, ...)
```

### Key Scopes
```ruby
User.providers              # All providers
User.customers              # All customers
provider.offices            # Offices managed by provider
provider.provider_appointments  # Appointments provider delivers
customer.appointments       # Appointments customer booked
Appointment.upcoming        # Future appointments
Appointment.confirmed       # Confirmed appointments
Office.active               # Active offices
```

---

Happy testing! 🚀

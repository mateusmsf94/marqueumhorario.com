# Rails Console Testing Guide - User Model

This guide provides step-by-step Rails console commands to manually test and explore the User model implementation, including all relationships with Offices and Appointments.

## Prerequisites

1. Ensure your database is migrated:
   ```bash
   rails db:migrate
   ```

2. Start Rails console:
   ```bash
   rails console
   ```

3. **(Optional)** Load test data:
   ```bash
   rails db:fixtures:load
   ```

---

## 1. User Model Basics

### 1.1 Create a Customer

```ruby
customer = User.create!(
  first_name: "Maria",
  last_name: "Silva",
  email: "maria@example.com",
  password: "password123",
  password_confirmation: "password123",
  roles: ["customer"],
  cpf: "12345678902",
  phone: "11987654321"
)
```

**Expected:** User created successfully

**Verify:**
```ruby
customer.customer?          # => true
customer.provider?          # => false
customer.full_name          # => "Maria Silva"
customer.roles              # => ["customer"]
customer.email              # => "maria@example.com"
```

### 1.2 Create a Provider

```ruby
provider = User.create!(
  first_name: "João",
  last_name: "Santos",
  email: "joao@example.com",
  password: "password123",
  password_confirmation: "password123",
  roles: ["provider"],
  cpf: "98765432101"
)
```

**Verify:**
```ruby
provider.provider?          # => true
provider.customer?          # => false
provider.roles              # => ["provider"]
```

### 1.3 Create a Multi-Role User (Provider AND Customer)

```ruby
# A provider who can also book appointments at other offices
multi_role = User.create!(
  first_name: "Carlos",
  last_name: "Oliveira",
  email: "carlos@example.com",
  password: "password123",
  password_confirmation: "password123",
  roles: ["provider", "customer"],
  cpf: "11122233399"
)
```

**Verify:**
```ruby
multi_role.provider?        # => true
multi_role.customer?        # => true
multi_role.roles            # => ["provider", "customer"]
multi_role.has_role?(:provider)  # => true
multi_role.has_role?(:customer)  # => true
```

### 1.4 Test Role Default

```ruby
# When roles are not specified, defaults to ["customer"]
default_user = User.create!(
  first_name: "Ana",
  last_name: "Costa",
  email: "ana@example.com",
  password: "password123",
  password_confirmation: "password123"
)

default_user.customer?      # => true
default_user.roles          # => ["customer"]
```

### 1.5 Add and Remove Roles Dynamically

```ruby
# Start with a customer
user = User.create!(
  first_name: "Beatriz",
  last_name: "Lima",
  email: "beatriz@example.com",
  password: "password123",
  password_confirmation: "password123"
  # roles defaults to ["customer"]
)

user.customer?              # => true
user.provider?              # => false

# User decides to also offer services - add provider role
user.add_role(:provider)

user.reload
user.customer?              # => true
user.provider?              # => true
user.roles                  # => ["customer", "provider"]

# Later, user stops providing services - remove provider role
user.remove_role(:provider)

user.reload
user.customer?              # => true
user.provider?              # => false
user.roles                  # => ["customer"]
```

---

## 2. User Model Validations

### 2.1 Required Fields

**Test missing first_name:**
```ruby
user = User.new(
  last_name: "Silva",
  email: "test@example.com",
  password: "password123",
  password_confirmation: "password123"
)

user.valid?                 # => false
user.errors[:first_name]    # => ["can't be blank"]
```

**Test missing last_name:**
```ruby
user = User.new(
  first_name: "Test",
  email: "test@example.com",
  password: "password123",
  password_confirmation: "password123"
)

user.valid?                 # => false
user.errors[:last_name]     # => ["can't be blank"]
```

### 2.2 Email Validation

**Test duplicate email:**
```ruby
# First user
user1 = User.create!(
  first_name: "User",
  last_name: "One",
  email: "duplicate@example.com",
  password: "password123",
  password_confirmation: "password123"
)

# Try to create second user with same email
user2 = User.new(
  first_name: "User",
  last_name: "Two",
  email: "duplicate@example.com",  # Same email!
  password: "password123",
  password_confirmation: "password123"
)

user2.valid?                # => false
user2.errors[:email]        # => ["has already been taken"]
```

### 2.3 CPF Validation

**Test valid CPF:**
```ruby
user = User.new(
  first_name: "Test",
  last_name: "User",
  email: "cpftest@example.com",
  password: "password123",
  password_confirmation: "password123",
  cpf: "12345678903"
)

user.valid?                 # => true
```

**Test CPF normalization (removes non-digits):**
```ruby
user = User.create!(
  first_name: "Test",
  last_name: "User",
  email: "formatted@example.com",
  password: "password123",
  password_confirmation: "password123",
  cpf: "123.456.789-04"      # Formatted CPF
)

user.cpf                    # => "12345678904" (normalized to digits only)
```

**Test invalid CPF (too short):**
```ruby
user = User.new(
  first_name: "Test",
  last_name: "User",
  email: "short@example.com",
  password: "password123",
  password_confirmation: "password123",
  cpf: "123456"              # Only 6 digits
)

user.valid?                 # => false
user.errors[:cpf]           # => ["is the wrong length (should be 11 characters)"]
```

**Test invalid CPF (all same digits):**
```ruby
user = User.new(
  first_name: "Test",
  last_name: "User",
  email: "same@example.com",
  password: "password123",
  password_confirmation: "password123",
  cpf: "11111111111"         # All same digit
)

user.valid?                 # => false
user.errors[:cpf]           # => ["is invalid"]
```

**Test CPF uniqueness:**
```ruby
# First user with CPF
user1 = User.create!(
  first_name: "First",
  last_name: "User",
  email: "first@example.com",
  password: "password123",
  password_confirmation: "password123",
  cpf: "11122233344"
)

# Try to create second user with same CPF
user2 = User.new(
  first_name: "Second",
  last_name: "User",
  email: "second@example.com",
  password: "password123",
  password_confirmation: "password123",
  cpf: "11122233344"         # Same CPF!
)

user2.valid?                # => false
user2.errors[:cpf]          # => ["has already been taken"]
```

**Test CPF is optional:**
```ruby
user = User.create!(
  first_name: "No",
  last_name: "CPF",
  email: "nocpf@example.com",
  password: "password123",
  password_confirmation: "password123"
  # cpf not provided
)

user.cpf                    # => nil
user.valid?                 # => true
```

---

## 3. User Scopes

### 3.1 Providers Scope

```ruby
# Get all providers
providers = User.providers

providers.count             # Number of providers
providers.first.provider?   # => true
```

### 3.2 Customers Scope

```ruby
# Get all customers
customers = User.customers

customers.count             # Number of customers
customers.first.customer?   # => true
```

### 3.3 With CPF Scope

```ruby
# Get all users with CPF
users_with_cpf = User.with_cpf

users_with_cpf.each do |user|
  puts "#{user.full_name}: #{user.cpf}"
end
```

---

## 4. Customer → Appointments Relationship

### 4.1 Create an Appointment for a Customer

First, ensure you have an office and a customer:

```ruby
# Create office
office = Office.create!(
  name: "Clínica Central",
  time_zone: "America/Sao_Paulo",
  address: "Rua das Flores, 123",
  city: "São Paulo",
  state: "SP"
)

# Create customer
customer = User.create!(
  first_name: "Carlos",
  last_name: "Mendes",
  email: "carlos@example.com",
  password: "password123",
  password_confirmation: "password123",
  roles: ["customer"],
  cpf: "11122233345"
)

# Create appointment for customer
appointment = Appointment.create!(
  office: office,
  customer: customer,
  title: "Consulta Geral",
  scheduled_at: 2.days.from_now,
  status: :pending
)
```

**Verify the relationship:**
```ruby
# From appointment to customer
appointment.customer            # => Customer object
appointment.customer.full_name  # => "Carlos Mendes"

# From customer to appointments
customer.appointments           # => [appointment]
customer.appointments.count     # => 1
```

### 4.2 Query Customer's Appointments

```ruby
# Get all appointments for a customer
customer_appointments = customer.appointments

# Get appointments by status
pending = customer.appointments.pending
confirmed = customer.appointments.confirmed

# Use the for_customer scope
Appointment.for_customer(customer.id)
```

### 4.3 Test Validation: Provider Cannot Be Appointment Customer

```ruby
# Create a provider
provider = User.create!(
  first_name: "Dr. Pedro",
  last_name: "Silva",
  email: "pedro@example.com",
  password: "password123",
  password_confirmation: "password123",
  roles: ["provider"]
)

# Try to create appointment with provider as customer
appointment = Appointment.new(
  office: office,
  customer: provider,        # Provider as customer - should fail!
  title: "Test",
  scheduled_at: 2.days.from_now
)

appointment.valid?             # => false
appointment.errors[:customer]  # => ["must have customer user type"]
```

---

## 5. Provider → Appointments Relationship

### 5.1 Create an Appointment with Provider

Appointments can have a provider assigned to deliver the service:

```ruby
# Create provider
provider = User.create!(
  first_name: "Dr. João",
  last_name: "Silva",
  email: "joao.silva@example.com",
  password: "password123",
  password_confirmation: "password123",
  roles: ["provider"]
)

# Create office
office = Office.create!(
  name: "Clínica Exemplo",
  time_zone: "America/Sao_Paulo",
  city: "São Paulo",
  state: "SP"
)

# Add provider to office
OfficeMembership.create!(
  user: provider,
  office: office,
  role: :owner
)

# Create customer
customer = User.create!(
  first_name: "Maria",
  last_name: "Santos",
  email: "maria.santos@example.com",
  password: "password123",
  password_confirmation: "password123",
  roles: ["customer"]
)

# Create appointment with provider
appointment = Appointment.create!(
  office: office,
  customer: customer,
  provider: provider,         # Provider assigned
  title: "Consulta Médica",
  scheduled_at: 2.days.from_now,
  status: :pending
)
```

**Verify the relationship:**
```ruby
# From appointment to provider
appointment.provider            # => Provider object
appointment.provider.full_name  # => "Dr. João Silva"

# From provider to appointments
provider.provider_appointments           # => [appointment]
provider.provider_appointments.count     # => 1
```

### 5.2 Query Provider's Appointments

```ruby
# Get all appointments for a provider
provider_appointments = provider.provider_appointments

# Get appointments by status
pending = provider.provider_appointments.pending
confirmed = provider.provider_appointments.confirmed

# Use the for_provider scope
Appointment.for_provider(provider.id)

# Chain with other scopes
upcoming_confirmed = provider.provider_appointments.upcoming.confirmed
```

### 5.3 Test Validation: Provider Must Have Provider User Type

```ruby
# Create a customer
customer_user = User.create!(
  first_name: "Carlos",
  last_name: "Mendes",
  email: "carlos@example.com",
  password: "password123",
  password_confirmation: "password123",
  roles: ["customer"]
)

# Try to assign customer as provider
appointment = Appointment.new(
  office: office,
  customer: customer,
  provider: customer_user,   # Customer as provider - should fail!
  title: "Test",
  scheduled_at: 2.days.from_now
)

appointment.valid?              # => false
appointment.errors[:provider]   # => ["must have provider user type"]
```

### 5.4 Test Validation: Provider Must Work at the Office

```ruby
# Create another office
other_office = Office.create!(
  name: "Outra Clínica",
  time_zone: "America/Sao_Paulo",
  city: "Rio de Janeiro",
  state: "RJ"
)

# Create provider who doesn't work at original office
other_provider = User.create!(
  first_name: "Dr. Pedro",
  last_name: "Costa",
  email: "pedro@example.com",
  password: "password123",
  password_confirmation: "password123",
  roles: ["provider"]
)

# Add provider only to other_office
OfficeMembership.create!(
  user: other_provider,
  office: other_office,
  role: :member
)

# Try to assign provider to appointment at different office
appointment = Appointment.new(
  office: office,              # Original office
  customer: customer,
  provider: other_provider,    # Provider works at other_office - should fail!
  title: "Test",
  scheduled_at: 2.days.from_now
)

appointment.valid?              # => false
appointment.errors[:provider]   # => ["must work at this office"]
```

### 5.5 Appointments Can Have Provider Without Customer

```ruby
# Create appointment with provider but no customer (e.g., blocked time)
blocked_time = Appointment.create!(
  office: office,
  provider: provider,
  title: "Blocked Time - Lunch",
  scheduled_at: 3.days.from_now.change(hour: 12, min: 0),
  status: :pending
  # No customer assigned
)

blocked_time.customer    # => nil
blocked_time.provider    # => provider
```

### 5.6 Find All Appointments a Provider Delivers

```ruby
# Get provider's upcoming appointments
provider = User.find_by(email: "joao.silva@example.com")

puts "\n#{provider.full_name}'s Upcoming Appointments:"
provider.provider_appointments.upcoming.each do |apt|
  puts "\n- #{apt.title}"
  puts "  Office: #{apt.office.name}"
  puts "  Customer: #{apt.customer&.full_name || 'No customer (blocked time)'}"
  puts "  When: #{apt.scheduled_at.strftime('%d/%m/%Y %H:%M')}"
  puts "  Status: #{apt.status}"
end

# Count by status
puts "\nAppointment Summary:"
puts "Pending: #{provider.provider_appointments.pending.count}"
puts "Confirmed: #{provider.provider_appointments.confirmed.count}"
puts "Completed: #{provider.provider_appointments.completed.count}"
puts "Total: #{provider.provider_appointments.count}"
```

---

## 6. Provider → Offices Relationship (via OfficeMemberships)

### 6.1 Create Office Membership

```ruby
# Create a provider
provider = User.create!(
  first_name: "Dr. Ana",
  last_name: "Lima",
  email: "ana.lima@example.com",
  password: "password123",
  password_confirmation: "password123",
  roles: ["provider"]
)

# Create an office
office = Office.create!(
  name: "Consultório Dr. Ana",
  time_zone: "America/Sao_Paulo",
  city: "Rio de Janeiro",
  state: "RJ"
)

# Create membership (provider manages office)
membership = OfficeMembership.create!(
  user: provider,
  office: office,
  role: :owner
)
```

**Verify the relationship:**
```ruby
# From provider to offices
provider.offices                # => [office]
provider.manages_office?(office) # => true

# From office to providers
office.users                    # => [provider]
office.managed_by?(provider)    # => true
```

### 6.2 Test Different Membership Roles

```ruby
# Create another provider
admin_user = User.create!(
  first_name: "Dr. Bruno",
  last_name: "Costa",
  email: "bruno@example.com",
  password: "password123",
  password_confirmation: "password123",
  roles: ["provider"]
)

# Add as admin
admin_membership = OfficeMembership.create!(
  user: admin_user,
  office: office,
  role: :admin
)

# Create member provider
member_user = User.create!(
  first_name: "Dr. Clara",
  last_name: "Souza",
  email: "clara@example.com",
  password: "password123",
  password_confirmation: "password123",
  roles: ["provider"]
)

# Add as member
member_membership = OfficeMembership.create!(
  user: member_user,
  office: office,
  role: :member
)
```

**Query by role:**
```ruby
# All memberships for the office
office.office_memberships

# Get only owners
office.office_memberships.owner

# Get only admins
office.office_memberships.admin

# Get only members
office.office_memberships.member
```

### 6.3 Test Validation: Customer Cannot Be Office Member

```ruby
# Create a customer
customer = User.create!(
  first_name: "Maria",
  last_name: "Santos",
  email: "maria.santos@example.com",
  password: "password123",
  password_confirmation: "password123",
  roles: ["customer"]
)

# Try to create membership with customer
membership = OfficeMembership.new(
  user: customer,           # Customer - should fail!
  office: office,
  role: :member
)

membership.valid?            # => false
membership.errors[:user]     # => ["must be a provider to manage offices"]
```

### 6.4 Active/Inactive Memberships

```ruby
# Deactivate a membership
membership = office.office_memberships.first
membership.deactivate!

membership.is_active        # => false

# Query only active memberships
office.office_memberships.active

# Get active managers
office.active_managers

# Reactivate
membership.activate!
membership.is_active        # => true
```

### 6.5 Test Unique Membership Constraint

```ruby
# Try to add same provider to same office twice
duplicate_membership = OfficeMembership.new(
  user: provider,
  office: office,
  role: :admin
)

duplicate_membership.valid?          # => false
duplicate_membership.errors[:user_id] # => ["is already a member of this office"]
```

---

## 7. Complete User Journey Simulation

### 7.1 Provider Onboarding Journey

```ruby
# 1. Provider signs up
provider = User.create!(
  first_name: "Dr. Roberto",
  last_name: "Oliveira",
  email: "roberto@example.com",
  password: "password123",
  password_confirmation: "password123",
  roles: ["provider"],
  cpf: "11122233346",
  phone: "11998887777"
)

# 2. Provider creates their office
office = Office.create!(
  name: "Clínica Dr. Roberto",
  time_zone: "America/Sao_Paulo",
  address: "Av. Paulista, 1000",
  city: "São Paulo",
  state: "SP",
  zip_code: "01310-100"
)

# 3. Provider becomes office owner
OfficeMembership.create!(
  user: provider,
  office: office,
  role: :owner
)

# 4. Provider sets up work schedule
work_schedule = WorkSchedule.create!(
  office: office,
  day_of_week: 1,  # Monday
  start_time: "09:00",
  end_time: "18:00",
  appointment_duration: 60,
  is_active: true
)

# Verify provider's setup
puts "Provider: #{provider.full_name}"
puts "Manages #{provider.offices.count} office(s)"
puts "Office: #{office.name}"
puts "Active: #{office.is_active}"
```

### 7.2 Customer Booking Journey

```ruby
# 1. Customer signs up
customer = User.create!(
  first_name: "Fernanda",
  last_name: "Rodrigues",
  email: "fernanda@example.com",
  password: "password123",
  password_confirmation: "password123",
  roles: ["customer"],
  phone: "11977776666"
)

# 2. Customer browses active offices
available_offices = Office.active

puts "Available offices:"
available_offices.each do |off|
  puts "- #{off.name} (#{off.city}, #{off.state})"
end

# 3. Customer books an appointment with specific provider
appointment = Appointment.create!(
  office: office,
  customer: customer,
  provider: provider,       # Assign the provider who will deliver the service
  title: "Consulta de Rotina",
  scheduled_at: 3.days.from_now.change(hour: 10, min: 0),
  status: :pending
)

# 4. Appointment is confirmed
appointment.update!(status: :confirmed)

# Verify customer's appointments
puts "\nCustomer: #{customer.full_name}"
puts "Appointments: #{customer.appointments.count}"
customer.appointments.each do |apt|
  puts "- #{apt.title} at #{apt.office.name} on #{apt.scheduled_at}"
  puts "  Status: #{apt.status}"
end
```

### 7.3 Provider Views Their Appointments

```ruby
# Method 1: Get appointments the provider personally delivers
provider_appointments = provider.provider_appointments

puts "\nAppointments #{provider.full_name} will deliver:"
provider_appointments.upcoming.each do |apt|
  puts "\n- #{apt.title}"
  puts "  Office: #{apt.office.name}"
  puts "  Customer: #{apt.customer&.full_name || 'No customer (blocked time)'}"
  puts "  When: #{apt.scheduled_at.strftime('%d/%m/%Y %H:%M')}"
  puts "  Status: #{apt.status}"
end

# Method 2: Get ALL appointments at offices the provider manages
all_office_appointments = Appointment.where(office_id: provider.office_ids)

puts "\n\nAll appointments at #{provider.full_name}'s offices:"
all_office_appointments.upcoming.each do |apt|
  puts "\n- #{apt.title}"
  puts "  Provider: #{apt.provider&.full_name || 'No provider assigned'}"
  puts "  Customer: #{apt.customer&.full_name || 'No customer'}"
  puts "  Office: #{apt.office.name}"
  puts "  When: #{apt.scheduled_at.strftime('%d/%m/%Y %H:%M')}"
  puts "  Status: #{apt.status}"
end
```

### 7.4 Multi-Role User: Provider Who Also Books Appointments

```ruby
# Create a multi-role user (provider AND customer)
dr_maria = User.create!(
  first_name: "Dr. Maria",
  last_name: "Cardoso",
  email: "maria.cardoso@example.com",
  password: "password123",
  password_confirmation: "password123",
  roles: ["provider", "customer"],
  cpf: "99988877766",
  phone: "11955554444"
)

# Dr. Maria runs her own office
marias_office = Office.create!(
  name: "Clínica Dra. Maria",
  time_zone: "America/Sao_Paulo",
  address: "Av. Brasil, 500",
  city: "São Paulo",
  state: "SP"
)

# Add Dr. Maria as owner
OfficeMembership.create!(
  user: dr_maria,
  office: marias_office,
  role: :owner
)

# Dr. Maria provides services to a customer at her office
customer = users(:customer_alice)

appointment_as_provider = Appointment.create!(
  office: marias_office,
  provider: dr_maria,      # Dr. Maria is the PROVIDER
  customer: customer,
  title: "Consulta Cardiológica",
  scheduled_at: 2.days.from_now.change(hour: 14, min: 0),
  status: :confirmed
)

puts "Appointment where Dr. Maria is the provider:"
puts "  Customer: #{appointment_as_provider.customer.full_name}"
puts "  Provider: #{appointment_as_provider.provider.full_name}"

# Dr. Maria also books an appointment at a dentist's office
dentist_office = offices(:another_office)
dentist = users(:provider_jane)

appointment_as_customer = Appointment.create!(
  office: dentist_office,
  customer: dr_maria,      # Dr. Maria is the CUSTOMER
  provider: dentist,
  title: "Consulta Odontológica",
  scheduled_at: 3.days.from_now.change(hour: 10, min: 0),
  status: :pending
)

puts "\nAppointment where Dr. Maria is the customer:"
puts "  Customer: #{appointment_as_customer.customer.full_name}"
puts "  Provider: #{appointment_as_customer.provider.full_name}"

# View Dr. Maria's two different appointment lists
puts "\n\n=== Dr. Maria's Appointments as PROVIDER (appointments she delivers) ==="
dr_maria.provider_appointments.each do |apt|
  puts "- #{apt.title} for #{apt.customer.full_name} on #{apt.scheduled_at.strftime('%d/%m/%Y %H:%M')}"
end

puts "\n=== Dr. Maria's Appointments as CUSTOMER (appointments she booked) ==="
dr_maria.appointments.each do |apt|
  puts "- #{apt.title} with #{apt.provider.full_name} on #{apt.scheduled_at.strftime('%d/%m/%Y %H:%M')}"
end

# Verify roles
puts "\n\nDr. Maria's roles:"
puts "  Roles: #{dr_maria.roles}"
puts "  Is provider? #{dr_maria.provider?}"
puts "  Is customer? #{dr_maria.customer?}"
puts "  Can manage offices? #{dr_maria.provider?}"
puts "  Can book appointments? #{dr_maria.customer?}"
```

**This demonstrates:**
- Same user can be both provider and customer
- `provider_appointments` - appointments they deliver as a provider
- `appointments` - appointments they booked as a customer
- Multi-role users appear in both `User.providers` and `User.customers` scopes

---

## 8. Advanced Queries

### 8.1 Find All Appointments for a Provider's Offices

```ruby
# Method 1: Using office_ids
provider = User.find_by(email: "roberto@example.com")
appointments = Appointment.where(office_id: provider.office_ids)

# Method 2: Using joins
appointments = Appointment.joins(office: :office_memberships)
                         .where(office_memberships: { user_id: provider.id })

appointments.count
```

### 8.2 Find All Active Providers

```ruby
active_providers = User.providers.joins(:office_memberships)
                      .where(office_memberships: { is_active: true })
                      .distinct

active_providers.each do |prov|
  puts "#{prov.full_name} - #{prov.offices.count} office(s)"
end
```

### 8.3 Find Offices in a Specific City with Their Managers

```ruby
city_offices = Office.by_city("São Paulo").includes(:providers)

city_offices.each do |office|
  puts "\n#{office.name}"
  puts "Managers:"
  office.providers.each do |provider|
    puts "  - #{provider.full_name}"
  end
end
```

### 8.4 Count Appointments by Status for a Customer

```ruby
customer = User.find_by(email: "fernanda@example.com")

puts "\nAppointment Summary for #{customer.full_name}:"
puts "Pending: #{customer.appointments.pending.count}"
puts "Confirmed: #{customer.appointments.confirmed.count}"
puts "Cancelled: #{customer.appointments.cancelled.count}"
puts "Completed: #{customer.appointments.completed.count}"
puts "Total: #{customer.appointments.count}"
```

### 8.5 Find Customers Who Booked at a Specific Office

```ruby
office = Office.find_by(name: "Clínica Central")

customers = User.joins(:appointments)
               .where(appointments: { office_id: office.id })
               .distinct

puts "Customers who booked at #{office.name}:"
customers.each do |customer|
  appointment_count = customer.appointments.where(office: office).count
  puts "- #{customer.full_name} (#{appointment_count} appointment(s))"
end
```

### 8.6 Find Appointments by Provider Across Multiple Offices

```ruby
# Find a provider who works at multiple offices
provider = User.providers.joins(:office_memberships).group('users.id').having('COUNT(office_memberships.id) > 1').first

# Get all appointments this provider delivers across all offices
appointments_by_office = provider.provider_appointments.includes(:office, :customer).group_by(&:office)

puts "\n#{provider.full_name}'s appointments across offices:"
appointments_by_office.each do |office, appointments|
  puts "\n#{office.name} (#{appointments.count} appointments):"
  appointments.each do |apt|
    puts "  - #{apt.title} | #{apt.customer&.full_name || 'No customer'} | #{apt.scheduled_at.strftime('%d/%m/%Y %H:%M')}"
  end
end
```

### 8.7 Find Appointments with Both Customer and Provider

```ruby
# Find all appointments that have both a customer and a provider assigned
complete_appointments = Appointment.where.not(customer_id: nil).where.not(provider_id: nil)

puts "Complete appointments (with customer and provider):"
complete_appointments.includes(:customer, :provider, :office).each do |apt|
  puts "\n#{apt.title} at #{apt.office.name}"
  puts "  Customer: #{apt.customer.full_name}"
  puts "  Provider: #{apt.provider.full_name}"
  puts "  When: #{apt.scheduled_at.strftime('%d/%m/%Y %H:%M')}"
  puts "  Status: #{apt.status}"
end

# Count appointments by assignment type
puts "\n\nAppointment assignment statistics:"
puts "With both customer and provider: #{Appointment.where.not(customer_id: nil).where.not(provider_id: nil).count}"
puts "With customer only: #{Appointment.where.not(customer_id: nil).where(provider_id: nil).count}"
puts "With provider only: #{Appointment.where(customer_id: nil).where.not(provider_id: nil).count}"
puts "With neither (placeholder): #{Appointment.where(customer_id: nil, provider_id: nil).count}"
```

---

## 9. Cleanup Commands

### Reset Data (Be Careful!)

```ruby
# Delete all users (will cascade to memberships and affect appointments)
User.destroy_all

# Delete all office memberships
OfficeMembership.destroy_all

# Delete all appointments
Appointment.destroy_all

# Delete all offices
Office.destroy_all
```

### Reload Fixtures

```bash
# Exit console first, then:
rails db:fixtures:load
```

---

## Tips & Tricks

### Check Current Data

```ruby
# Count records
puts "Users: #{User.count}"
puts "Providers: #{User.providers.count}"
puts "Customers: #{User.customers.count}"
puts "Offices: #{Office.count}"
puts "Memberships: #{OfficeMembership.count}"
puts "Appointments: #{Appointment.count}"
```

### Find Records

```ruby
# Find by email
user = User.find_by(email: "example@example.com")

# Find by CPF
user = User.find_by(cpf: "12345678902")

# Find by name
users = User.where("first_name ILIKE ?", "%maria%")
```

### Update Records

```ruby
user = User.find_by(email: "example@example.com")
user.update!(phone: "11999998888")
```

### Inspect Relationships

```ruby
user = User.first
user.offices                    # Offices user manages (if provider)
user.appointments               # Appointments user booked (if customer)
user.office_memberships         # Membership details
```

---

## Common Errors and Solutions

### "Validation failed: Email has already been taken"
**Solution:** Use a different email address

### "Validation failed: User must be a provider to manage offices"
**Solution:** Ensure the user has `roles: ["provider"]`

### "Validation failed: Customer must have customer user type"
**Solution:** Only customers can be assigned to appointments as customers

### "CPF is the wrong length"
**Solution:** Ensure CPF has exactly 11 digits

### "CPF is invalid"
**Solution:** Don't use CPFs with all the same digits (e.g., "11111111111")

---

## Next Steps

1. Try creating your own test scenarios
2. Explore complex queries using joins
3. Test edge cases and error handling
4. Experiment with scopes and associations
5. Build realistic workflows for your application

Happy testing! 🚀

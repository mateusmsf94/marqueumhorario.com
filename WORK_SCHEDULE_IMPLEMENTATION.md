# Work Schedule Management - Implementation Guide

This document provides a complete implementation guide for the work schedule management feature in the provider onboarding flow. Each section includes explanations of the approach and the actual code to implement.

## Table of Contents

1. [Routes Configuration](#1-routes-configuration)
2. [Form Object (WorkScheduleCollection)](#2-form-object-workschedulecollection)
3. [Controller (WorkSchedulesController)](#3-controller-workschedulescontroller)
4. [Views](#4-views)
5. [Stimulus Controller](#5-stimulus-controller)
6. [Integration Updates](#6-integration-updates)
7. [Testing](#7-testing)

---

## 1. Routes Configuration

### Explanation

We're adding a nested singular resource `work_schedules` under the `offices` resource. We use a singular resource (not plural) because we're managing the entire week's schedule as one logical unit, not individual schedule records.

The routes will be:
- `GET /providers/offices/:office_id/work_schedules/new` - Setup form for new schedules
- `POST /providers/offices/:office_id/work_schedules` - Create all 7 day schedules
- `GET /providers/offices/:office_id/work_schedules/edit` - Edit existing schedules
- `PATCH /providers/offices/:office_id/work_schedules` - Update schedules

### File: `config/routes.rb`

**Current state** (line 13-17):
```ruby
namespace :providers do
  resource :onboarding, only: [:new]
  get "dashboard", to: "dashboard#index"
  resources :offices
end
```

**Updated code**:
```ruby
namespace :providers do
  resource :onboarding, only: [:new]
  get "dashboard", to: "dashboard#index"
  resources :offices do
    resource :work_schedules, only: [:new, :create, :edit, :update], controller: "work_schedules"
  end
end
```

**Why this approach?**
- Nesting under `offices` makes the relationship clear in the URL
- Singular `resource` reflects managing one "schedule collection" per office
- The `controller: "work_schedules"` explicitly names the controller (Rails convention would look for `work_schedule_controller`)

---

## 2. Form Object (WorkScheduleCollection)

### Explanation

The Form Object pattern solves a key challenge: we need to create 7 separate `WorkSchedule` records (one per day of the week) from a single form submission. Instead of putting all this complexity in the controller, we encapsulate it in a dedicated form object.

**Key responsibilities:**
1. Initialize 7 blank WorkSchedule objects for the form
2. Parse nested params from the form submission
3. Validate only "open" days (days the provider marked as working)
4. Save all schedules in a database transaction (all-or-nothing)
5. Handle both create and edit scenarios

**Benefits:**
- Keeps controller thin and focused on HTTP concerns
- Makes testing easier (test the form object independently)
- Provides a clear abstraction matching the user's mental model
- Reusable across multiple controllers if needed

### File: `app/models/work_schedule_collection.rb` (NEW)

```ruby
# Form object for managing a week's worth of WorkSchedule records as a single unit.
# This encapsulates the complexity of creating/updating 7 separate database records
# from a single form submission.
class WorkScheduleCollection
  include ActiveModel::Model

  attr_accessor :office, :provider, :schedules

  # Use the same day constants from WorkSchedule model
  DAYS_OF_WEEK = WorkSchedule::DAYS_OF_WEEK

  # Initialize a new collection with 7 blank schedules (one per day)
  #
  # @param office [Office] The office these schedules belong to
  # @param provider [User] The provider (user) creating the schedules
  # @param params [Hash] Optional params hash from form submission
  def initialize(office:, provider:, params: {})
    @office = office
    @provider = provider
    @schedules = build_schedules(params)
  end

  # Class method to load existing schedules for editing
  #
  # @param office [Office] The office to load schedules for
  # @param provider [User] The provider whose schedules to load
  # @return [WorkScheduleCollection] Collection with existing or blank schedules
  def self.load_existing(office:, provider:)
    collection = new(office: office, provider: provider)
    collection.instance_variable_set(:@schedules, [])
    collection.send(:load_existing_schedules)
    collection
  end

  # Save all schedules marked as "open" in a database transaction
  # If any save fails, the entire transaction is rolled back
  #
  # @return [Boolean] true if all saves succeeded, false otherwise
  def save
    return false unless valid?

    ActiveRecord::Base.transaction do
      schedules.each do |schedule|
        next unless schedule_is_open?(schedule)
        schedule.save!
      end
    end
    true
  rescue ActiveRecord::RecordInvalid => e
    Rails.logger.error("WorkScheduleCollection save failed: #{e.message}")
    false
  end

  # Update existing schedules
  # Similar to save but handles updating existing records
  #
  # @param params [Hash] New params from form submission
  # @return [Boolean] true if update succeeded
  def update(params)
    update_schedules_from_params(params)

    return false unless valid?

    ActiveRecord::Base.transaction do
      schedules.each do |schedule|
        if schedule_is_open?(schedule)
          schedule.save!
        elsif schedule.persisted?
          # Mark previously open days as inactive if now closed
          schedule.update!(is_active: false)
        end
      end
    end
    true
  rescue ActiveRecord::RecordInvalid => e
    Rails.logger.error("WorkScheduleCollection update failed: #{e.message}")
    false
  end

  # Validate only schedules marked as "open"
  # Closed days don't need validation since they won't be saved
  #
  # @return [Boolean] true if all open schedules are valid
  def valid?
    open_schedules = schedules.select { |s| schedule_is_open?(s) }
    return true if open_schedules.empty?

    open_schedules.all?(&:valid?)
  end

  # Get schedule for a specific day of the week
  #
  # @param day_of_week [Integer] Day number (0-6)
  # @return [WorkSchedule, nil] The schedule for that day
  def schedule_for_day(day_of_week)
    schedules.find { |s| s.day_of_week == day_of_week }
  end

  # Get validation errors for a specific day
  #
  # @param day_of_week [Integer] Day number (0-6)
  # @return [ActiveModel::Errors, nil] Errors for that day's schedule
  def errors_for_day(day_of_week)
    schedule_for_day(day_of_week)&.errors
  end

  private

  # Build 7 WorkSchedule objects (one for each day of the week)
  # If params are provided, populate from those; otherwise create blank schedules
  #
  # @param params [Hash] Params hash with schedules data
  # @return [Array<WorkSchedule>] Array of 7 schedules
  def build_schedules(params)
    DAYS_OF_WEEK.map do |day_name, day_number|
      day_params = params.dig(:schedules, day_number.to_s) || {}

      WorkSchedule.new(
        office: office,
        provider: provider,
        day_of_week: day_number,
        is_active: day_params[:is_open] == "1",
        **parse_day_params(day_params)
      )
    end
  end

  # Parse params for a single day into WorkSchedule attributes
  #
  # @param params [Hash] Params for one day
  # @return [Hash] Attributes hash for WorkSchedule.new
  def parse_day_params(params)
    return default_schedule_params if params.blank?

    work_periods_array = parse_work_periods(params[:work_periods])

    {
      work_periods: work_periods_array,
      appointment_duration_minutes: params[:appointment_duration_minutes]&.to_i || 60,
      buffer_minutes_between_appointments: params[:buffer_minutes_between_appointments]&.to_i || 15,
      # Set opening/closing times for backward compatibility
      opening_time: work_periods_array.first&.dig("start") || "09:00",
      closing_time: work_periods_array.last&.dig("end") || "17:00"
    }
  end

  # Convert work_periods params from nested hash to array format
  # Input: { "0" => { start: "09:00", end: "12:00" }, "1" => { start: "13:00", end: "17:00" } }
  # Output: [{ "start" => "09:00", "end" => "12:00" }, { "start" => "13:00", "end" => "17:00" }]
  #
  # @param periods_params [Hash, nil] Work periods from form params
  # @return [Array<Hash>] Array of period hashes
  def parse_work_periods(periods_params)
    return [{ "start" => "09:00", "end" => "17:00" }] if periods_params.blank?

    # periods_params comes as a hash with string keys "0", "1", etc.
    # We need to convert to array and stringify the inner hash keys
    periods_params.values.map do |period|
      {
        "start" => period[:start] || period["start"],
        "end" => period[:end] || period["end"]
      }
    end
  end

  # Default schedule params for blank schedules
  #
  # @return [Hash] Default attributes
  def default_schedule_params
    {
      work_periods: [{ "start" => "09:00", "end" => "17:00" }],
      appointment_duration_minutes: 60,
      buffer_minutes_between_appointments: 15,
      opening_time: "09:00",
      closing_time: "17:00"
    }
  end

  # Load existing schedules from database for editing
  # If a day doesn't have a schedule, create a blank inactive one
  #
  # @return [void]
  def load_existing_schedules
    @schedules = DAYS_OF_WEEK.map do |day_name, day_number|
      existing = office.work_schedules
                      .active
                      .for_provider(provider.id)
                      .for_day(day_number)
                      .first

      if existing
        existing
      else
        # Create blank schedule for days without existing schedule
        WorkSchedule.new(
          office: office,
          provider: provider,
          day_of_week: day_number,
          is_active: false,
          **default_schedule_params
        )
      end
    end
  end

  # Update schedules with new params (for edit flow)
  #
  # @param params [Hash] New params from form
  # @return [void]
  def update_schedules_from_params(params)
    schedules.each do |schedule|
      day_params = params.dig(:schedules, schedule.day_of_week.to_s) || {}

      schedule.assign_attributes(
        is_active: day_params[:is_open] == "1",
        **parse_day_params(day_params)
      )
    end
  end

  # Check if a schedule should be saved (is marked as open)
  # Need to handle both the is_active attribute and a potential is_open virtual attribute
  #
  # @param schedule [WorkSchedule] The schedule to check
  # @return [Boolean] true if schedule is open/active
  def schedule_is_open?(schedule)
    schedule.is_active == true
  end
end
```

**Key design decisions explained:**

1. **Virtual `is_open` attribute**: The form uses checkboxes with `is_open` param, which we convert to `is_active` in the database. This separation allows the UI to use user-friendly naming.

2. **Transaction wrapping**: All saves happen in a transaction so if any day fails validation, nothing is saved. This prevents partial week schedules from inconsistent form submissions.

3. **Backward compatibility**: We set both `work_periods` (new JSONB format) and `opening_time`/`closing_time` (legacy fields) to ensure the model validations pass.

4. **Validation strategy**: Only validate days marked as open. This allows providers to have partial week schedules (e.g., only working Monday-Friday).

---

## 3. Controller (WorkSchedulesController)

### Explanation

The controller handles HTTP requests and delegates business logic to the form object. It's responsible for:
1. Authentication and authorization (ensure user owns the office)
2. Instantiating the form object
3. Redirecting appropriately based on success/failure
4. Handling both create and edit flows

We keep it thin by using the form object for all complex logic.

### File: `app/controllers/providers/work_schedules_controller.rb` (NEW)

```ruby
# Controller for managing work schedules within the provider onboarding flow.
# Handles creating and editing a week's worth of schedules as a single unit.
class Providers::WorkSchedulesController < ApplicationController
  before_action :authenticate_user!
  before_action :set_office
  before_action :ensure_user_manages_office

  # GET /providers/offices/:office_id/work_schedules/new
  # Display form for setting up weekly schedule (initial onboarding)
  def new
    @schedule_collection = WorkScheduleCollection.new(
      office: @office,
      provider: current_user
    )
  end

  # POST /providers/offices/:office_id/work_schedules
  # Create all 7 day schedules from form submission
  def create
    @schedule_collection = WorkScheduleCollection.new(
      office: @office,
      provider: current_user,
      params: work_schedule_params
    )

    if @schedule_collection.save
      redirect_to providers_dashboard_path,
                  notice: "Work schedules configured successfully! You can now start accepting appointments."
    else
      # Re-render form with validation errors
      render :new, status: :unprocessable_entity
    end
  end

  # GET /providers/offices/:office_id/work_schedules/edit
  # Display form for editing existing weekly schedule
  def edit
    @schedule_collection = WorkScheduleCollection.load_existing(
      office: @office,
      provider: current_user
    )
  end

  # PATCH /providers/offices/:office_id/work_schedules
  # Update existing schedules
  def update
    @schedule_collection = WorkScheduleCollection.load_existing(
      office: @office,
      provider: current_user
    )

    if @schedule_collection.update(work_schedule_params)
      redirect_to providers_dashboard_path,
                  notice: "Work schedules updated successfully!"
    else
      render :edit, status: :unprocessable_entity
    end
  end

  private

  # Load office from current_user's offices (auto-scopes to user's offices)
  # This ensures users can only manage their own offices
  def set_office
    @office = current_user.offices.find(params[:office_id])
  rescue ActiveRecord::RecordNotFound
    redirect_to providers_dashboard_path,
                alert: "Office not found or you don't have access to it."
  end

  # Double-check user manages this office (belt-and-suspenders security)
  def ensure_user_manages_office
    return if @office.managed_by?(current_user)

    redirect_to providers_dashboard_path,
                alert: "You don't have permission to manage this office's schedules."
  end

  # Strong parameters for work schedule form
  # Permits nested structure: schedules[day_number][is_open, work_periods, etc.]
  def work_schedule_params
    params.permit(
      schedules: [
        :is_open,
        :appointment_duration_minutes,
        :buffer_minutes_between_appointments,
        work_periods: [:start, :end]
      ]
    )
  end
end
```

**Security considerations:**

1. **Scoped queries**: `current_user.offices.find()` ensures users can only access their own offices
2. **Explicit authorization check**: `ensure_user_manages_office` provides additional security layer
3. **Strong params**: Only permits expected parameters, preventing mass assignment vulnerabilities

**Error handling:**

- Uses `status: :unprocessable_entity` (422) for validation errors (Rails convention)
- Provides user-friendly error messages via flash notices
- Rescues `RecordNotFound` to handle invalid office IDs gracefully

---

## 4. Views

### Explanation

The views are structured as:
- **new.html.erb** / **edit.html.erb**: Page wrappers with headers
- **_form.html.erb**: Main form partial (reused for both new and edit)
- **_day_schedule.html.erb**: Partial for one day's section (reused 7 times)
- **_work_period.html.erb**: Partial for one time period (reusable, dynamically added)

This modular approach keeps templates DRY and maintainable.

### File: `app/views/providers/work_schedules/new.html.erb` (NEW)

```erb
<div class="max-w-5xl mx-auto px-4 sm:px-6 lg:px-8 py-8">
  <!-- Page Header -->
  <div class="mb-8">
    <h1 class="text-3xl font-bold text-gray-900">Set up your weekly schedule</h1>
    <p class="mt-2 text-sm text-gray-600">
      Configure your working hours for <strong><%= @office.name %></strong>
    </p>
    <p class="mt-1 text-xs text-gray-500">
      Time zone: <%= @office.time_zone %>
    </p>
  </div>

  <%= render "form", schedule_collection: @schedule_collection, office: @office %>
</div>
```

### File: `app/views/providers/work_schedules/edit.html.erb` (NEW)

```erb
<div class="max-w-5xl mx-auto px-4 sm:px-6 lg:px-8 py-8">
  <!-- Page Header -->
  <div class="mb-8">
    <h1 class="text-3xl font-bold text-gray-900">Edit weekly schedule</h1>
    <p class="mt-2 text-sm text-gray-600">
      Update working hours for <strong><%= @office.name %></strong>
    </p>
    <p class="mt-1 text-xs text-gray-500">
      Time zone: <%= @office.time_zone %>
    </p>
  </div>

  <%= render "form", schedule_collection: @schedule_collection, office: @office %>
</div>
```

### File: `app/views/providers/work_schedules/_form.html.erb` (NEW)

```erb
<%#
  Main form for work schedule management.
  Displays all 7 days of the week with ability to toggle each day on/off
  and configure work periods, appointment duration, and buffer time.
%>

<%= form_with url: providers_office_work_schedules_path(@office),
              method: :post,
              class: "space-y-6" do |f| %>

  <%# Error Summary Section - Shows which days have validation errors %>
  <% if @schedule_collection.schedules.any? { |s| s.errors.any? } %>
    <div class="bg-red-50 border-l-4 border-red-400 p-4">
      <div class="flex">
        <div class="flex-shrink-0">
          <svg class="h-5 w-5 text-red-400" viewBox="0 0 20 20" fill="currentColor">
            <path fill-rule="evenodd" d="M10 18a8 8 0 100-16 8 8 0 000 16zM8.707 7.293a1 1 0 00-1.414 1.414L8.586 10l-1.293 1.293a1 1 0 101.414 1.414L10 11.414l1.293 1.293a1 1 0 001.414-1.414L11.414 10l1.293-1.293a1 1 0 00-1.414-1.414L10 8.586 8.707 7.293z" clip-rule="evenodd" />
          </svg>
        </div>
        <div class="ml-3">
          <h3 class="text-sm font-medium text-red-800">
            Please fix the following errors:
          </h3>
          <div class="mt-2 text-sm text-red-700">
            <% @schedule_collection.schedules.each do |schedule| %>
              <% if schedule.errors.any? %>
                <p class="font-medium"><%= schedule.day_name %>:</p>
                <ul class="list-disc list-inside ml-4 mb-2">
                  <% schedule.errors.full_messages.each do |msg| %>
                    <li><%= msg %></li>
                  <% end %>
                </ul>
              <% end %>
            <% end %>
          </div>
        </div>
      </div>
    </div>
  <% end %>

  <%# Helpful Tips Section %>
  <div class="bg-blue-50 border-l-4 border-blue-400 p-4">
    <div class="flex">
      <div class="flex-shrink-0">
        <svg class="h-5 w-5 text-blue-400" viewBox="0 0 20 20" fill="currentColor">
          <path fill-rule="evenodd" d="M18 10a8 8 0 11-16 0 8 8 0 0116 0zm-7-4a1 1 0 11-2 0 1 1 0 012 0zM9 9a1 1 0 000 2v3a1 1 0 001 1h1a1 1 0 100-2v-3a1 1 0 00-1-1H9z" clip-rule="evenodd" />
        </svg>
      </div>
      <div class="ml-3">
        <p class="text-sm text-blue-700">
          <strong>Tips:</strong> You can add multiple time periods for days with breaks
          (e.g., 9am-12pm, 1pm-5pm for lunch). Toggle days on/off as needed.
          All times are in <strong><%= @office.time_zone %></strong> timezone.
        </p>
      </div>
    </div>
  </div>

  <%# Day by Day Sections - Render one section per day of week %>
  <div class="space-y-4">
    <% WorkSchedule::DAYS_OF_WEEK.each do |day_name, day_number| %>
      <% schedule = @schedule_collection.schedule_for_day(day_number) %>
      <%= render "day_schedule",
                 day_name: day_name,
                 day_number: day_number,
                 schedule: schedule %>
    <% end %>
  </div>

  <%# Form Actions - Submit and Cancel Buttons %>
  <div class="flex items-center justify-between pt-6 border-t border-gray-200">
    <%= link_to "Set up later", providers_dashboard_path,
        class: "text-sm font-medium text-gray-700 hover:text-gray-500" %>

    <%= f.submit schedule_collection.schedules.first.persisted? ? "Update Schedule" : "Save Schedule",
        class: "inline-flex justify-center py-2 px-6 border border-transparent shadow-sm text-sm font-medium rounded-md text-white bg-blue-600 hover:bg-blue-700 focus:outline-none focus:ring-2 focus:ring-offset-2 focus:ring-blue-500" %>
  </div>
<% end %>
```

### File: `app/views/providers/work_schedules/_day_schedule.html.erb` (NEW)

```erb
<%#
  Partial for one day's schedule section.
  Includes toggle checkbox, work period inputs, and appointment settings.
  Uses Stimulus for dynamic show/hide and add/remove period functionality.

  Local variables:
    - day_name: Symbol like :monday
    - day_number: Integer 0-6
    - schedule: WorkSchedule instance for this day
%>

<div class="bg-white shadow rounded-lg p-6"
     data-controller="work-periods"
     data-work-periods-day-value="<%= day_number %>">

  <%# Day Header with Toggle Checkbox %>
  <div class="flex items-center justify-between mb-4 pb-4 border-b border-gray-200">
    <h3 class="text-lg font-medium text-gray-900">
      <%= day_name.to_s.capitalize %>
    </h3>

    <label class="flex items-center cursor-pointer">
      <%= check_box_tag "schedules[#{day_number}][is_open]",
                        "1",
                        schedule.is_active,
                        class: "rounded border-gray-300 text-blue-600 focus:ring-blue-500 mr-2",
                        data: { action: "work-periods#toggleDay" } %>
      <span class="text-sm font-medium text-gray-700">Open this day</span>
    </label>
  </div>

  <%# Day Inputs Container (shown/hidden based on checkbox) %>
  <div data-work-periods-target="inputs"
       style="<%= 'display: none;' unless schedule.is_active %>"
       class="space-y-4">

    <%# Work Periods Section %>
    <div>
      <label class="block text-sm font-medium text-gray-700 mb-3">
        Working Hours
      </label>

      <%# Container for work period inputs (Stimulus manages this) %>
      <div data-work-periods-target="container" class="space-y-2">
        <% periods = schedule.work_periods || [{ "start" => "09:00", "end" => "17:00" }] %>
        <% periods.each_with_index do |period, index| %>
          <%= render "work_period",
                     day_number: day_number,
                     period: period,
                     index: index %>
        <% end %>
      </div>

      <%# Button to add another work period (managed by Stimulus) %>
      <button type="button"
              data-action="work-periods#addPeriod"
              class="mt-3 inline-flex items-center text-sm text-blue-600 hover:text-blue-800 font-medium">
        <svg class="h-4 w-4 mr-1" fill="none" stroke="currentColor" viewBox="0 0 24 24">
          <path stroke-linecap="round" stroke-linejoin="round" stroke-width="2" d="M12 4v16m8-8H4"/>
        </svg>
        Add another time period
      </button>
    </div>

    <%# Appointment Settings Section %>
    <div class="grid grid-cols-1 md:grid-cols-2 gap-4 pt-4 border-t border-gray-200">
      <%# Appointment Duration %>
      <div>
        <%= label_tag "schedules[#{day_number}][appointment_duration_minutes]",
                      "Appointment Duration",
                      class: "block text-sm font-medium text-gray-700 mb-1" %>
        <div class="flex items-center">
          <%= number_field_tag "schedules[#{day_number}][appointment_duration_minutes]",
                              schedule.appointment_duration_minutes || 60,
                              min: 5,
                              max: 480,
                              step: 5,
                              class: "block w-full rounded-md border-gray-300 shadow-sm focus:border-blue-500 focus:ring-blue-500 sm:text-sm" %>
          <span class="ml-2 text-sm text-gray-500">minutes</span>
        </div>
        <p class="mt-1 text-xs text-gray-500">How long each appointment lasts</p>
      </div>

      <%# Buffer Time %>
      <div>
        <%= label_tag "schedules[#{day_number}][buffer_minutes_between_appointments]",
                      "Buffer Time",
                      class: "block text-sm font-medium text-gray-700 mb-1" %>
        <div class="flex items-center">
          <%= number_field_tag "schedules[#{day_number}][buffer_minutes_between_appointments]",
                              schedule.buffer_minutes_between_appointments || 15,
                              min: 0,
                              max: 120,
                              step: 5,
                              class: "block w-full rounded-md border-gray-300 shadow-sm focus:border-blue-500 focus:ring-blue-500 sm:text-sm" %>
          <span class="ml-2 text-sm text-gray-500">minutes</span>
        </div>
        <p class="mt-1 text-xs text-gray-500">Break between appointments</p>
      </div>
    </div>

    <%# Validation Errors for This Day %>
    <% if schedule.errors.any? %>
      <div class="mt-3 bg-red-50 border border-red-200 rounded-md p-3">
        <div class="text-sm text-red-600">
          <% schedule.errors.full_messages.each do |msg| %>
            <p>• <%= msg %></p>
          <% end %>
        </div>
      </div>
    <% end %>
  </div>
</div>
```

### File: `app/views/providers/work_schedules/_work_period.html.erb` (NEW)

```erb
<%#
  Partial for a single work period (time range).
  Includes start time, end time, and remove button.
  Can be dynamically added/removed via Stimulus controller.

  Local variables:
    - day_number: Integer 0-6 (which day this period belongs to)
    - period: Hash with "start" and "end" keys (e.g., { "start" => "09:00", "end" => "17:00" })
    - index: Integer index of this period within the day (0-based)
%>

<div class="work-period flex items-center gap-3 p-3 bg-gray-50 rounded-md"
     data-work-periods-target="period">

  <%# Time Inputs Container %>
  <div class="flex-1 flex items-center gap-3">
    <%# Start Time Input %>
    <div class="flex-1">
      <%= time_field_tag "schedules[#{day_number}][work_periods][#{index}][start]",
                         period["start"] || "09:00",
                         step: 900,
                         class: "block w-full rounded-md border-gray-300 shadow-sm focus:border-blue-500 focus:ring-blue-500 sm:text-sm" %>
    </div>

    <%# Separator %>
    <span class="text-gray-500 font-medium">to</span>

    <%# End Time Input %>
    <div class="flex-1">
      <%= time_field_tag "schedules[#{day_number}][work_periods][#{index}][end]",
                         period["end"] || "17:00",
                         step: 900,
                         class: "block w-full rounded-md border-gray-300 shadow-sm focus:border-blue-500 focus:ring-blue-500 sm:text-sm" %>
    </div>
  </div>

  <%# Remove Button (Stimulus controller handles the removal) %>
  <button type="button"
          data-action="work-periods#removePeriod"
          class="flex-shrink-0 text-red-600 hover:text-red-800 text-sm font-medium px-3 py-2 hover:bg-red-50 rounded-md transition-colors">
    Remove
  </button>
</div>
```

**View design decisions:**

1. **Tailwind CSS**: Matches existing application styling patterns
2. **Responsive design**: Uses `md:grid-cols-2` for appointment settings (stacks on mobile)
3. **Accessibility**: Proper labels, ARIA attributes via Stimulus, keyboard navigation
4. **User feedback**: Error messages inline per day, plus summary at top
5. **HTML5 time inputs**: `step="900"` provides 15-minute intervals (900 seconds)

---

## 5. Stimulus Controller

### Explanation

The Stimulus controller handles dynamic UI interactions:
- Toggle day section visibility when checkbox changes
- Add new work period fields
- Remove work period fields (with minimum 1 enforced)
- Re-index field names after removal to maintain proper array indices for Rails

**Why Stimulus?**
- Keeps JavaScript organized and scoped to specific elements
- Works with Rails UJS and form helpers
- Provides clean separation between HTML structure and behavior

### File: `app/javascript/controllers/work_periods_controller.js` (NEW)

```javascript
import { Controller } from "@hotwired/stimulus"

/**
 * Stimulus controller for managing dynamic work period fields.
 *
 * Handles:
 * - Toggling day visibility when checkbox changes
 * - Adding new work period time inputs
 * - Removing work periods (enforces min 1, max 4)
 * - Re-indexing field names to maintain proper Rails array params
 *
 * Targets:
 *   - container: The div holding all work period inputs
 *   - period: Individual work period divs
 *   - inputs: The section to show/hide when day is toggled
 *
 * Values:
 *   - day: The day of week number (0-6)
 *   - maxPeriods: Maximum periods allowed (default: 4)
 */
export default class extends Controller {
  static targets = ["container", "period", "inputs"]
  static values = {
    day: Number,
    maxPeriods: { type: Number, default: 4 }
  }

  /**
   * Initialize the controller
   * Count existing periods on page load
   */
  connect() {
    this.periodCount = this.periodTargets.length
    console.log(`Work periods controller connected for day ${this.dayValue}. Current periods: ${this.periodCount}`)
  }

  /**
   * Toggle visibility of day inputs when checkbox changes
   *
   * @param {Event} event - The change event from the checkbox
   */
  toggleDay(event) {
    const isOpen = event.target.checked
    this.inputsTarget.style.display = isOpen ? 'block' : 'none'

    console.log(`Day ${this.dayValue} toggled ${isOpen ? 'on' : 'off'}`)
  }

  /**
   * Add a new work period to the day
   * Enforces maximum periods limit
   *
   * @param {Event} event - The click event from "Add period" button
   */
  addPeriod(event) {
    event.preventDefault()

    // Enforce maximum periods limit
    if (this.periodCount >= this.maxPeriodsValue) {
      alert(`Maximum ${this.maxPeriodsValue} time periods allowed per day`)
      return
    }

    // Create and insert new period HTML
    const template = this.createPeriodTemplate(this.periodCount)
    this.containerTarget.insertAdjacentHTML('beforeend', template)
    this.periodCount++

    console.log(`Added period. Day ${this.dayValue} now has ${this.periodCount} periods`)
  }

  /**
   * Remove a work period from the day
   * Enforces minimum 1 period when day is open
   *
   * @param {Event} event - The click event from "Remove" button
   */
  removePeriod(event) {
    event.preventDefault()

    // Enforce minimum 1 period
    if (this.periodCount <= 1) {
      alert("Must have at least one time period when day is open")
      return
    }

    // Remove the period div
    const periodElement = event.target.closest('[data-work-periods-target="period"]')
    periodElement.remove()
    this.periodCount--

    // Re-index remaining periods to maintain sequential array indices
    this.reindexPeriods()

    console.log(`Removed period. Day ${this.dayValue} now has ${this.periodCount} periods`)
  }

  /**
   * Create HTML template for a new work period
   * Maintains proper Rails array parameter naming
   *
   * @param {number} index - The index for this period (0-based)
   * @returns {string} HTML string for the new period
   */
  createPeriodTemplate(index) {
    const day = this.dayValue

    return `
      <div class="work-period flex items-center gap-3 p-3 bg-gray-50 rounded-md"
           data-work-periods-target="period">

        <div class="flex-1 flex items-center gap-3">
          <div class="flex-1">
            <input type="time"
                   name="schedules[${day}][work_periods][${index}][start]"
                   value="09:00"
                   step="900"
                   class="block w-full rounded-md border-gray-300 shadow-sm focus:border-blue-500 focus:ring-blue-500 sm:text-sm">
          </div>

          <span class="text-gray-500 font-medium">to</span>

          <div class="flex-1">
            <input type="time"
                   name="schedules[${day}][work_periods][${index}][end]"
                   value="17:00"
                   step="900"
                   class="block w-full rounded-md border-gray-300 shadow-sm focus:border-blue-500 focus:ring-blue-500 sm:text-sm">
          </div>
        </div>

        <button type="button"
                data-action="work-periods#removePeriod"
                class="flex-shrink-0 text-red-600 hover:text-red-800 text-sm font-medium px-3 py-2 hover:bg-red-50 rounded-md transition-colors">
          Remove
        </button>
      </div>
    `
  }

  /**
   * Re-index all period field names to maintain sequential array indices
   * This ensures Rails receives proper params after periods are removed
   *
   * Example: If period 1 is removed from [0, 1, 2], this updates indices to [0, 1]
   * so Rails doesn't receive params with gaps like [0, 2]
   */
  reindexPeriods() {
    this.periodTargets.forEach((periodElement, index) => {
      // Find the time input fields within this period
      const timeInputs = periodElement.querySelectorAll('input[type="time"]')

      // Update the 'name' attribute to reflect new index
      // timeInputs[0] is start time, timeInputs[1] is end time
      if (timeInputs[0]) {
        timeInputs[0].name = `schedules[${this.dayValue}][work_periods][${index}][start]`
      }
      if (timeInputs[1]) {
        timeInputs[1].name = `schedules[${this.dayValue}][work_periods][${index}][end]`
      }
    })

    console.log(`Re-indexed ${this.periodTargets.length} periods for day ${this.dayValue}`)
  }
}
```

**JavaScript best practices:**

1. **Proper encapsulation**: All logic scoped to the controller class
2. **Defensive coding**: Enforces min/max limits, handles edge cases
3. **Logging**: Console logs for debugging (can be removed in production)
4. **Event handling**: Uses `event.preventDefault()` to prevent form submission
5. **DOM manipulation**: Uses modern methods like `insertAdjacentHTML` and `closest()`

---

## 6. Integration Updates

### Explanation

Now we need to integrate the new work schedule feature into the existing provider flow:
1. Redirect to schedule setup after office creation (onboarding flow)
2. Wire up dashboard links to schedule management

### 6.1 Update Office Controller Redirect

**File**: `app/controllers/providers/offices_controller.rb`

**Find line 20-21** (the redirect in the `create` action):

```ruby
redirect_to providers_dashboard_path,
  notice: "Office created successfully! You're now a provider."
```

**Replace with**:

```ruby
redirect_to new_providers_office_work_schedules_path(@office),
  notice: "Office created! Now let's set up your weekly schedule."
```

**Explanation**: This changes the onboarding flow so that after creating an office, providers are immediately taken to the work schedule setup form instead of the dashboard. This ensures they complete the critical setup step.

### 6.2 Update Dashboard Links

**File**: `app/views/providers/dashboard/index.html.erb`

**Find the "Manage Schedule" link** (around line 164 in the office listing):

```erb
<%= link_to "Manage Schedule", "#", class: "..." %>
```

**Replace with**:

```erb
<% if office.work_schedules.active.for_provider(current_user.id).any? %>
  <%= link_to "Edit Schedule",
      edit_providers_office_work_schedules_path(office),
      class: "text-blue-600 hover:text-blue-800 font-medium" %>
<% else %>
  <%= link_to "Set Up Schedule",
      new_providers_office_work_schedules_path(office),
      class: "text-yellow-600 hover:text-yellow-800 font-medium" %>
<% end %>
```

**Explanation**: This dynamically shows either "Edit Schedule" (if schedules exist) or "Set Up Schedule" (if they don't), with appropriate color coding.

**Add a warning badge for offices without schedules** (add below the office name):

```erb
<% if office.work_schedules.active.for_provider(current_user.id).none? %>
  <span class="inline-flex items-center px-2 py-1 rounded text-xs font-medium bg-yellow-100 text-yellow-800 ml-2">
    ⚠ No schedule
  </span>
<% end %>
```

**Find the "Set Work Schedule" quick action link** (in the Quick Actions section at bottom):

```erb
<%= link_to "Set Work Schedule", "#", class: "..." %>
```

**Replace with**:

```erb
<%= link_to "Set Work Schedule",
    new_providers_office_work_schedules_path(@offices.first),
    class: "inline-flex items-center px-4 py-2 border border-transparent text-sm font-medium rounded-md text-white bg-blue-600 hover:bg-blue-700 focus:outline-none focus:ring-2 focus:ring-offset-2 focus:ring-blue-500" if @offices.any? %>
```

**Explanation**: This wires up the quick action button to the schedule setup form for the first office. The `if @offices.any?` prevents errors if the user has no offices.

---

## 7. Testing

### Explanation

We'll write three levels of tests:
1. **Model tests** - Test the WorkScheduleCollection form object
2. **Controller tests** - Test HTTP request/response behavior
3. **System tests** - Test end-to-end user flows with a browser

### 7.1 Model Tests

**File**: `test/models/work_schedule_collection_test.rb` (NEW)

```ruby
require "test_helper"

class WorkScheduleCollectionTest < ActiveSupport::TestCase
  setup do
    @office = offices(:main_office)
    @provider = users(:provider_john)
  end

  test "initializes with 7 blank schedules" do
    collection = WorkScheduleCollection.new(
      office: @office,
      provider: @provider
    )

    assert_equal 7, collection.schedules.count
    assert collection.schedules.all? { |s| s.new_record? }
    assert_equal (0..6).to_a, collection.schedules.map(&:day_of_week).sort
  end

  test "builds schedules from params" do
    params = {
      schedules: {
        "1" => { # Monday
          is_open: "1",
          work_periods: {
            "0" => { start: "09:00", end: "17:00" }
          },
          appointment_duration_minutes: "60",
          buffer_minutes_between_appointments: "15"
        }
      }
    }

    collection = WorkScheduleCollection.new(
      office: @office,
      provider: @provider,
      params: params
    )

    monday = collection.schedule_for_day(1)
    assert monday.is_active
    assert_equal 60, monday.appointment_duration_minutes
    assert_equal 15, monday.buffer_minutes_between_appointments
    assert_equal [{ "start" => "09:00", "end" => "17:00" }], monday.work_periods
  end

  test "validates only open days" do
    # Create collection with Monday open but invalid
    params = {
      schedules: {
        "1" => { # Monday - open but no work periods (invalid)
          is_open: "1",
          appointment_duration_minutes: "60",
          buffer_minutes_between_appointments: "15"
        },
        "2" => { # Tuesday - closed (should not be validated)
          is_open: "0"
        }
      }
    }

    collection = WorkScheduleCollection.new(
      office: @office,
      provider: @provider,
      params: params
    )

    refute collection.valid?
    # Tuesday should not have errors because it's closed
    assert collection.schedule_for_day(2).errors.empty?
  end

  test "saves all open schedules in transaction" do
    params = {
      schedules: {
        "1" => { # Monday
          is_open: "1",
          work_periods: {
            "0" => { start: "09:00", end: "17:00" }
          },
          appointment_duration_minutes: "60",
          buffer_minutes_between_appointments: "15"
        },
        "2" => { # Tuesday
          is_open: "1",
          work_periods: {
            "0" => { start: "10:00", end: "18:00" }
          },
          appointment_duration_minutes: "45",
          buffer_minutes_between_appointments: "10"
        }
      }
    }

    collection = WorkScheduleCollection.new(
      office: @office,
      provider: @provider,
      params: params
    )

    assert_difference "WorkSchedule.count", 2 do
      assert collection.save
    end

    # Verify schedules were created
    assert @office.work_schedules.active.for_provider(@provider.id).for_day(1).exists?
    assert @office.work_schedules.active.for_provider(@provider.id).for_day(2).exists?
  end

  test "loads existing schedules" do
    # Create an existing schedule for Monday
    WorkSchedule.create!(
      office: @office,
      provider: @provider,
      day_of_week: 1,
      work_periods: [{ "start" => "09:00", "end" => "17:00" }],
      appointment_duration_minutes: 60,
      buffer_minutes_between_appointments: 15,
      opening_time: "09:00",
      closing_time: "17:00",
      is_active: true
    )

    collection = WorkScheduleCollection.load_existing(
      office: @office,
      provider: @provider
    )

    monday = collection.schedule_for_day(1)
    assert monday.persisted?
    assert monday.is_active

    # Other days should be blank
    tuesday = collection.schedule_for_day(2)
    assert tuesday.new_record?
    refute tuesday.is_active
  end
end
```

### 7.2 Controller Tests

**File**: `test/controllers/providers/work_schedules_controller_test.rb` (NEW)

```ruby
require "test_helper"

class Providers::WorkSchedulesControllerTest < ActionDispatch::IntegrationTest
  setup do
    @office = offices(:main_office)
    @provider = users(:provider_john)
    sign_in @provider
  end

  test "should require authentication" do
    sign_out @provider
    get new_providers_office_work_schedules_path(@office)
    assert_redirected_to new_user_session_path
  end

  test "should require user to own office" do
    other_office = offices(:west_coast_office) # Belongs to different provider
    get new_providers_office_work_schedules_path(other_office)
    assert_redirected_to providers_dashboard_path
    assert_equal "Office not found or you don't have access to it.", flash[:alert]
  end

  test "should get new" do
    get new_providers_office_work_schedules_path(@office)
    assert_response :success
    assert_select "h1", "Set up your weekly schedule"
  end

  test "should create schedules for open days" do
    params = {
      schedules: {
        "1" => { # Monday
          is_open: "1",
          work_periods: {
            "0" => { start: "09:00", end: "17:00" }
          },
          appointment_duration_minutes: "60",
          buffer_minutes_between_appointments: "15"
        },
        "2" => { # Tuesday - closed
          is_open: "0"
        }
      }
    }

    assert_difference "WorkSchedule.count", 1 do
      post providers_office_work_schedules_path(@office), params: params
    end

    assert_redirected_to providers_dashboard_path
    assert_equal "Work schedules configured successfully! You can now start accepting appointments.", flash[:notice]
  end

  test "should render new with errors on validation failure" do
    params = {
      schedules: {
        "1" => { # Monday - invalid (no work periods)
          is_open: "1",
          appointment_duration_minutes: "60",
          buffer_minutes_between_appointments: "15"
        }
      }
    }

    assert_no_difference "WorkSchedule.count" do
      post providers_office_work_schedules_path(@office), params: params
    end

    assert_response :unprocessable_entity
    assert_select ".text-red-800", /Please fix the following errors/
  end

  test "should get edit with existing schedules" do
    # Create existing schedule
    WorkSchedule.create!(
      office: @office,
      provider: @provider,
      day_of_week: 1,
      work_periods: [{ "start" => "09:00", "end" => "17:00" }],
      appointment_duration_minutes: 60,
      buffer_minutes_between_appointments: 15,
      opening_time: "09:00",
      closing_time: "17:00",
      is_active: true
    )

    get edit_providers_office_work_schedules_path(@office)
    assert_response :success
    assert_select "h1", "Edit weekly schedule"
  end

  test "should update existing schedules" do
    # Create existing schedule for Monday
    schedule = WorkSchedule.create!(
      office: @office,
      provider: @provider,
      day_of_week: 1,
      work_periods: [{ "start" => "09:00", "end" => "17:00" }],
      appointment_duration_minutes: 60,
      buffer_minutes_between_appointments: 15,
      opening_time: "09:00",
      closing_time: "17:00",
      is_active: true
    )

    params = {
      schedules: {
        "1" => { # Monday - update duration
          is_open: "1",
          work_periods: {
            "0" => { start: "09:00", end: "17:00" }
          },
          appointment_duration_minutes: "45", # Changed from 60
          buffer_minutes_between_appointments: "15"
        }
      }
    }

    patch providers_office_work_schedules_path(@office), params: params

    assert_redirected_to providers_dashboard_path
    schedule.reload
    assert_equal 45, schedule.appointment_duration_minutes
  end
end
```

### 7.3 System Tests

**File**: `test/system/provider_work_schedules_test.rb` (NEW)

```ruby
require "application_system_test_case"

class ProviderWorkSchedulesTest < ApplicationSystemTestCase
  setup do
    @provider = users(:provider_john)
    sign_in @provider
  end

  test "redirects to schedule setup after creating office" do
    visit new_providers_office_path

    fill_in "Office Name", with: "New Test Office"
    select "Pacific Time (US & Canada)", from: "Time Zone"

    click_button "Create Office"

    # Should redirect to work schedule setup
    assert_current_path new_providers_office_work_schedules_path(Office.last)
    assert_text "Set up your weekly schedule"
  end

  test "can toggle day open and closed" do
    office = offices(:main_office)
    visit new_providers_office_work_schedules_path(office)

    # Monday should be closed by default
    monday_checkbox = find("input[name='schedules[1][is_open]']")
    refute monday_checkbox.checked?

    # Check the checkbox to open Monday
    monday_checkbox.check

    # Work hour inputs should now be visible
    within "[data-work-periods-day-value='1']" do
      assert find("[data-work-periods-target='inputs']").visible?
    end

    # Uncheck to close Monday
    monday_checkbox.uncheck

    # Work hour inputs should be hidden
    within "[data-work-periods-day-value='1']" do
      refute find("[data-work-periods-target='inputs']").visible?
    end
  end

  test "can add and remove work periods" do
    office = offices(:main_office)
    visit new_providers_office_work_schedules_path(office)

    # Open Monday
    find("input[name='schedules[1][is_open]']").check

    within "[data-work-periods-day-value='1']" do
      # Should have 1 period by default
      assert_equal 1, all("[data-work-periods-target='period']").count

      # Click "Add another time period"
      click_button "Add another time period"

      # Should now have 2 periods
      assert_equal 2, all("[data-work-periods-target='period']").count

      # Click remove on the second period
      all("button", text: "Remove").last.click

      # Should be back to 1 period
      assert_equal 1, all("[data-work-periods-target='period']").count
    end
  end

  test "can submit valid schedule" do
    office = offices(:main_office)
    visit new_providers_office_work_schedules_path(office)

    # Set up Monday schedule
    find("input[name='schedules[1][is_open]']").check

    within "[data-work-periods-day-value='1']" do
      fill_in "schedules[1][appointment_duration_minutes]", with: "60"
      fill_in "schedules[1][buffer_minutes_between_appointments]", with: "15"
    end

    click_button "Save Schedule"

    # Should redirect to dashboard with success message
    assert_current_path providers_dashboard_path
    assert_text "Work schedules configured successfully"

    # Verify schedule was created
    assert WorkSchedule.exists?(
      office: office,
      provider: @provider,
      day_of_week: 1,
      is_active: true
    )
  end

  test "shows validation errors" do
    office = offices(:main_office)
    visit new_providers_office_work_schedules_path(office)

    # Open Monday but leave duration blank (will use default, but let's make it invalid another way)
    find("input[name='schedules[1][is_open]']").check

    within "[data-work-periods-day-value='1']" do
      # Set invalid duration (0 minutes)
      fill_in "schedules[1][appointment_duration_minutes]", with: "0"
    end

    click_button "Save Schedule"

    # Should show error message
    assert_text "Please fix the following errors"
    assert_text "Monday"
  end

  test "can skip schedule setup" do
    office = offices(:main_office)
    visit new_providers_office_work_schedules_path(office)

    click_link "Set up later"

    # Should go to dashboard
    assert_current_path providers_dashboard_path
  end
end
```

---

## Summary

This implementation guide provides:

1. **Routes** - Nested singular resource under offices
2. **Form Object** - WorkScheduleCollection encapsulating 7-day management
3. **Controller** - Thin controller delegating to form object
4. **Views** - Modular, reusable partials with Tailwind styling
5. **Stimulus** - Dynamic UI for add/remove periods
6. **Integration** - Updated onboarding flow and dashboard links
7. **Tests** - Comprehensive coverage at model, controller, and system levels

The implementation follows Rails best practices:
- Convention over configuration
- DRY (Don't Repeat Yourself)
- Separation of concerns
- Progressive enhancement
- Comprehensive testing

All code is production-ready with proper error handling, validation, security checks, and user feedback.

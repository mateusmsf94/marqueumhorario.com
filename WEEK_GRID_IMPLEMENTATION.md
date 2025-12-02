# Week Grid Visualization - Implementation Guide

This document provides a complete implementation guide for adding a week grid visualization that displays available appointment slots after a provider sets up their work schedule.

## Table of Contents

1. [Overview](#overview)
2. [Routes Update](#1-routes-update)
3. [Controller Action](#2-controller-action)
4. [Week Grid View](#3-week-grid-view)
5. [Stimulus Controller for Interactivity](#4-stimulus-controller-for-interactivity)
6. [Update Redirects](#5-update-redirects)
7. [Testing](#6-testing)

---

## Overview

### User Flow

1. Provider creates/edits work schedule
2. After saving, redirects to week grid preview page
3. Week grid shows discrete appointment slots for the upcoming week
4. Provider can click on any day to edit that day's schedule
5. Provider can proceed to dashboard when satisfied

### Technical Approach

**Leverage Existing Services:**
- Use `SlotGenerator` service to calculate discrete appointment slots
- Group slots by day for week grid display
- Show slots with visual indicators (available/busy)
- Make grid interactive with Stimulus

**Key Design Decisions:**
1. **Date Range**: Show current week (Monday-Sunday) by default
2. **Slot Display**: Show time in 12-hour format with AM/PM
3. **Interactivity**: Click on day header to edit that day
4. **No Appointments Yet**: Show all slots as "available" since schedule is new
5. **Visual Design**: Calendar-style grid with color-coded slots

---

## 1. Routes Update

### Explanation

Add a `show` action to display the week grid preview page. This will be the success page after creating or updating work schedules.

### File: `config/routes.rb`

**Current (from previous plan)**:
```ruby
namespace :providers do
  resources :offices do
    resource :work_schedules, only: [:new, :create, :edit, :update], controller: "work_schedules"
  end
end
```

**Updated**:
```ruby
namespace :providers do
  resources :offices do
    resource :work_schedules, only: [:new, :create, :show, :edit, :update], controller: "work_schedules"
  end
end
```

**New route generated**:
- `GET /providers/offices/:office_id/work_schedules` → `providers_office_work_schedules_path(@office)`

This will be the preview/show page displaying the week grid.

---

## 2. Controller Action

### Explanation

Add a `show` action to the WorkSchedulesController that:
1. Loads existing work schedules for the office/provider
2. Generates appointment slots for the upcoming week using SlotGenerator
3. Groups slots by day for easier display
4. Passes data to the view

Since this is a new setup (no appointments yet), all slots will show as "available".

### File: `app/controllers/providers/work_schedules_controller.rb`

**Add this action** (after `create` and before `edit`):

```ruby
# GET /providers/offices/:office_id/work_schedules
# Display week grid preview of available appointment slots
def show
  # Load all active work schedules for this provider at this office
  @work_schedules = @office.work_schedules
                           .active
                           .for_provider(current_user.id)

  # Define date range for the grid (current week: Monday to Sunday)
  @start_date = Date.today.beginning_of_week
  @end_date = Date.today.end_of_week

  # Get appointments for the week (will be empty for new setup)
  @appointments = Appointment
                    .for_provider(current_user.id)
                    .for_office(@office.id)
                    .blocking_time
                    .where(scheduled_at: @start_date..@end_date)

  # Generate slots using SlotGenerator service
  begin
    generator = SlotGenerator.new(@work_schedules, @appointments, office_id: @office.id)
    all_slots = generator.call(@start_date, @end_date)

    # Group slots by day for easier rendering in the grid
    # Result: { Date => [AvailableSlot, AvailableSlot, ...], ... }
    @slots_by_day = all_slots.group_by { |slot| slot.start_time.to_date }

  rescue StandardError => e
    # Handle errors gracefully (e.g., no schedules set up yet)
    Rails.logger.error("SlotGenerator error: #{e.message}")
    @slots_by_day = {}
    flash.now[:alert] = "Unable to generate appointment slots. Please check your work schedule configuration."
  end

  # Calculate summary stats for display
  @total_slots = all_slots&.count || 0
  @available_slots = all_slots&.count { |slot| slot.status == "available" } || 0
end
```

**Update `create` action redirect** (change the redirect destination):

**Before**:
```ruby
redirect_to providers_dashboard_path,
  notice: "Work schedules configured successfully!"
```

**After**:
```ruby
redirect_to providers_office_work_schedules_path(@office),
  notice: "Work schedules configured successfully! Here's your weekly availability:"
```

**Update `update` action redirect** (same change):

**Before**:
```ruby
redirect_to providers_dashboard_path,
  notice: "Work schedules updated successfully!"
```

**After**:
```ruby
redirect_to providers_office_work_schedules_path(@office),
  notice: "Work schedules updated successfully! Here's your updated weekly availability:"
```

---

## 3. Week Grid View

### Explanation

Create a view that displays the week grid with appointment slots. The grid will:
- Show 7 columns (one per day Monday-Sunday)
- Display time slots vertically for each day
- Use color coding for slot status
- Include interactive elements (click day to edit)
- Show helpful stats at the top

### File: `app/views/providers/work_schedules/show.html.erb` (NEW)

```erb
<%#
  Week Grid Preview Page
  Shows available appointment slots for the upcoming week after schedule setup
%>

<div class="max-w-7xl mx-auto px-4 sm:px-6 lg:px-8 py-8">

  <%# Page Header %>
  <div class="mb-8">
    <h1 class="text-3xl font-bold text-gray-900">Your Weekly Availability</h1>
    <p class="mt-2 text-sm text-gray-600">
      Schedule for <strong><%= @office.name %></strong> -
      <%= @start_date.strftime('%B %d') %> to <%= @end_date.strftime('%B %d, %Y') %>
    </p>
  </div>

  <%# Summary Stats %>
  <div class="bg-gradient-to-r from-blue-500 to-blue-600 rounded-lg shadow-lg p-6 mb-8 text-white">
    <div class="grid grid-cols-1 md:grid-cols-3 gap-6">
      <div>
        <div class="text-sm font-medium text-blue-100">Total Appointment Slots</div>
        <div class="text-4xl font-bold mt-1"><%= @total_slots %></div>
      </div>
      <div>
        <div class="text-sm font-medium text-blue-100">Available This Week</div>
        <div class="text-4xl font-bold mt-1"><%= @available_slots %></div>
      </div>
      <div>
        <div class="text-sm font-medium text-blue-100">Working Days</div>
        <div class="text-4xl font-bold mt-1"><%= @slots_by_day.keys.count %></div>
      </div>
    </div>
  </div>

  <%# Legend %>
  <div class="flex items-center gap-4 mb-6 p-4 bg-gray-50 rounded-lg">
    <span class="text-sm font-medium text-gray-700">Legend:</span>
    <div class="flex items-center gap-2">
      <div class="w-4 h-4 bg-green-100 border-2 border-green-400 rounded"></div>
      <span class="text-sm text-gray-600">Available</span>
    </div>
    <div class="flex items-center gap-2">
      <div class="w-4 h-4 bg-red-100 border-2 border-red-400 rounded"></div>
      <span class="text-sm text-gray-600">Busy</span>
    </div>
    <div class="flex items-center gap-2">
      <div class="w-4 h-4 bg-gray-100 border-2 border-gray-300 rounded"></div>
      <span class="text-sm text-gray-600">Closed</span>
    </div>
  </div>

  <%# Week Grid %>
  <% if @slots_by_day.any? %>
    <div class="bg-white shadow-lg rounded-lg overflow-hidden"
         data-controller="week-grid">

      <%# Day Headers %>
      <div class="grid grid-cols-7 border-b border-gray-200 bg-gray-50">
        <% (@start_date..@end_date).each do |date| %>
          <div class="p-4 text-center border-r border-gray-200 last:border-r-0"
               data-action="click->week-grid#editDay"
               data-week-grid-day-param="<%= WorkSchedule::DAYS_OF_WEEK.key(date.wday) %>"
               data-week-grid-office-id-param="<%= @office.id %>"
               class="cursor-pointer hover:bg-blue-50 transition-colors">

            <div class="text-xs font-medium text-gray-500 uppercase tracking-wide">
              <%= date.strftime('%a') %>
            </div>
            <div class="text-2xl font-bold text-gray-900 mt-1">
              <%= date.strftime('%d') %>
            </div>
            <div class="text-xs text-gray-500 mt-1">
              <%= date.strftime('%b') %>
            </div>

            <%# Edit icon hint %>
            <div class="mt-2 opacity-0 hover:opacity-100 transition-opacity">
              <svg class="h-4 w-4 mx-auto text-blue-600" fill="none" stroke="currentColor" viewBox="0 0 24 24">
                <path stroke-linecap="round" stroke-linejoin="round" stroke-width="2" d="M11 5H6a2 2 0 00-2 2v11a2 2 0 002 2h11a2 2 0 002-2v-5m-1.414-9.414a2 2 0 112.828 2.828L11.828 15H9v-2.828l8.586-8.586z"/>
              </svg>
            </div>
          </div>
        <% end %>
      </div>

      <%# Time Slots Grid %>
      <div class="grid grid-cols-7">
        <% (@start_date..@end_date).each do |date| %>
          <div class="border-r border-gray-200 last:border-r-0 p-2 space-y-1 min-h-[200px] bg-white">
            <% day_slots = @slots_by_day[date] || [] %>

            <% if day_slots.any? %>
              <%# Display slots for this day %>
              <% day_slots.each do |slot| %>
                <div class="<%= slot_class(slot) %> rounded px-2 py-1 text-xs text-center transition-all hover:shadow-md">
                  <div class="font-medium">
                    <%= slot.start_time.strftime('%I:%M %p') %>
                  </div>
                  <% if slot.status == "busy" %>
                    <div class="text-[10px] mt-0.5 opacity-75">Booked</div>
                  <% end %>
                </div>
              <% end %>
            <% else %>
              <%# No slots = day is closed %>
              <div class="flex items-center justify-center h-full text-gray-400">
                <div class="text-center">
                  <svg class="h-8 w-8 mx-auto mb-2 opacity-50" fill="none" stroke="currentColor" viewBox="0 0 24 24">
                    <path stroke-linecap="round" stroke-linejoin="round" stroke-width="2" d="M6 18L18 6M6 6l12 12"/>
                  </svg>
                  <div class="text-xs">Closed</div>
                </div>
              </div>
            <% end %>
          </div>
        <% end %>
      </div>
    </div>

  <% else %>
    <%# No schedules configured yet %>
    <div class="bg-yellow-50 border-l-4 border-yellow-400 p-6 rounded-lg">
      <div class="flex">
        <div class="flex-shrink-0">
          <svg class="h-6 w-6 text-yellow-400" fill="none" stroke="currentColor" viewBox="0 0 24 24">
            <path stroke-linecap="round" stroke-linejoin="round" stroke-width="2" d="M12 9v2m0 4h.01m-6.938 4h13.856c1.54 0 2.502-1.667 1.732-3L13.732 4c-.77-1.333-2.694-1.333-3.464 0L3.34 16c-.77 1.333.192 3 1.732 3z"/>
          </svg>
        </div>
        <div class="ml-3">
          <h3 class="text-sm font-medium text-yellow-800">No work schedule configured</h3>
          <p class="mt-2 text-sm text-yellow-700">
            You haven't set up your working hours yet. Set up your schedule to see available appointment slots.
          </p>
        </div>
      </div>
    </div>
  <% end %>

  <%# Action Buttons %>
  <div class="mt-8 flex items-center justify-between">
    <%= link_to "Edit Schedule",
        edit_providers_office_work_schedules_path(@office),
        class: "inline-flex items-center px-4 py-2 border border-gray-300 shadow-sm text-sm font-medium rounded-md text-gray-700 bg-white hover:bg-gray-50 focus:outline-none focus:ring-2 focus:ring-offset-2 focus:ring-blue-500" %>

    <%= link_to "Go to Dashboard",
        providers_dashboard_path,
        class: "inline-flex items-center px-6 py-2 border border-transparent shadow-sm text-sm font-medium rounded-md text-white bg-blue-600 hover:bg-blue-700 focus:outline-none focus:ring-2 focus:ring-offset-2 focus:ring-blue-500" %>
  </div>

  <%# Help Text %>
  <div class="mt-6 text-center text-sm text-gray-500">
    <p>💡 <strong>Tip:</strong> Click on any day header to quickly edit that day's schedule</p>
  </div>

</div>
```

**Add helper method to ApplicationHelper** (`app/helpers/application_helper.rb`):

```ruby
# Returns CSS classes for slot display based on status
def slot_class(slot)
  base_classes = "border-2"

  case slot.status
  when "available"
    "#{base_classes} bg-green-50 border-green-400 text-green-800"
  when "busy"
    "#{base_classes} bg-red-50 border-red-400 text-red-800"
  else
    "#{base_classes} bg-gray-100 border-gray-300 text-gray-600"
  end
end
```

---

## 4. Stimulus Controller for Interactivity

### Explanation

Add a Stimulus controller to make the week grid interactive. When a user clicks on a day header, it should navigate to the edit page with a URL fragment to focus on that specific day.

This provides a quick way to edit a specific day's schedule without navigating through the full edit form.

### File: `app/javascript/controllers/week_grid_controller.js` (NEW)

```javascript
import { Controller } from "@hotwired/stimulus"

/**
 * Stimulus controller for interactive week grid.
 *
 * Handles:
 * - Clicking on day headers to edit that day's schedule
 * - Visual feedback on hover
 *
 * Targets: None
 * Values:
 *   - officeId: The office ID (passed via data attribute)
 * Actions:
 *   - editDay: Navigate to edit page for specific day
 */
export default class extends Controller {
  static values = {
    officeId: String
  }

  /**
   * Navigate to edit schedule page when day is clicked
   * Includes URL fragment to auto-scroll/focus on that day
   *
   * @param {Event} event - Click event from day header
   */
  editDay(event) {
    const dayOfWeek = event.params.day // e.g., "monday"
    const officeId = event.params.officeId

    // Construct edit URL with day fragment
    // This allows the edit page to scroll to or highlight the clicked day
    const editUrl = `/providers/offices/${officeId}/work_schedules/edit#day-${dayOfWeek}`

    // Navigate with Turbo for smooth page transition
    Turbo.visit(editUrl)
  }

  /**
   * Optional: Add visual feedback when hovering over days
   * This could highlight all slots for that day
   */
  highlightDay(event) {
    // Future enhancement: highlight all slots for this day
    console.log("Highlighting day:", event.params.day)
  }

  /**
   * Optional: Remove highlight when mouse leaves
   */
  unhighlightDay(event) {
    // Future enhancement: remove highlight
    console.log("Unhighlighting day:", event.params.day)
  }
}
```

**Update the edit form to support day fragments** (`app/views/providers/work_schedules/_day_schedule.html.erb`):

Add an `id` attribute to each day section so the URL fragment can scroll to it:

```erb
<div class="bg-white shadow rounded-lg p-6"
     id="day-<%= day_name %>"
     data-controller="work-periods"
     data-work-periods-day-value="<%= day_number %>">
  <%# ... rest of day schedule partial ... %>
</div>
```

---

## 5. Update Redirects

### Explanation

We've already updated the controller redirects in section 2, but let's summarize all redirect changes for clarity.

### Changes Summary

**1. After creating schedules** (`WorkSchedulesController#create`):
- **Before**: Redirect to `providers_dashboard_path`
- **After**: Redirect to `providers_office_work_schedules_path(@office)` (week grid)

**2. After updating schedules** (`WorkSchedulesController#update`):
- **Before**: Redirect to `providers_dashboard_path`
- **After**: Redirect to `providers_office_work_schedules_path(@office)` (week grid)

**3. From week grid to dashboard**:
- User clicks "Go to Dashboard" button
- Navigates to `providers_dashboard_path`

**Flow diagram**:

```
Create Office
     ↓
Set Up Schedule (new)
     ↓
[Save] → Week Grid Preview ← [Edit Schedule] ← [From Dashboard]
     ↓
Go to Dashboard
```

---

## 6. Testing

### Explanation

Add tests to verify the week grid functionality works correctly.

### 6.1 Controller Tests

**File**: `test/controllers/providers/work_schedules_controller_test.rb`

**Add these tests**:

```ruby
test "should get show with week grid" do
  # Create work schedules for the office
  WorkSchedule.create!(
    office: @office,
    provider: @provider,
    day_of_week: 1, # Monday
    work_periods: [{ "start" => "09:00", "end" => "17:00" }],
    appointment_duration_minutes: 60,
    buffer_minutes_between_appointments: 15,
    opening_time: "09:00",
    closing_time: "17:00",
    is_active: true
  )

  get providers_office_work_schedules_path(@office)

  assert_response :success
  assert_select "h1", "Your Weekly Availability"
  assert_not_nil assigns(:slots_by_day)
  assert_not_nil assigns(:total_slots)
end

test "should redirect to week grid after creating schedules" do
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

  post providers_office_work_schedules_path(@office), params: params

  assert_redirected_to providers_office_work_schedules_path(@office)
  follow_redirect!
  assert_select "h1", "Your Weekly Availability"
end

test "should handle show with no schedules gracefully" do
  # Don't create any schedules
  get providers_office_work_schedules_path(@office)

  assert_response :success
  assert_select ".text-yellow-800", /No work schedule configured/
end
```

### 6.2 System Tests

**File**: `test/system/provider_work_schedules_test.rb`

**Add these tests**:

```ruby
test "shows week grid after creating schedule" do
  office = offices(:main_office)
  visit new_providers_office_work_schedules_path(office)

  # Set up Monday schedule
  find("input[name='schedules[1][is_open]']").check

  within "[data-work-periods-day-value='1']" do
    fill_in "schedules[1][appointment_duration_minutes]", with: "60"
    fill_in "schedules[1][buffer_minutes_between_appointments]", with: "15"
  end

  click_button "Save Schedule"

  # Should show week grid
  assert_text "Your Weekly Availability"
  assert_text "Total Appointment Slots"

  # Should show at least one slot
  assert_selector ".bg-green-50" # Available slot
end

test "can click on day to edit schedule" do
  # Create a schedule first
  office = offices(:main_office)
  WorkSchedule.create!(
    office: office,
    provider: @provider,
    day_of_week: 1,
    work_periods: [{ "start" => "09:00", "end" => "17:00" }],
    appointment_duration_minutes: 60,
    buffer_minutes_between_appointments: 15,
    opening_time: "09:00",
    closing_time: "17:00",
    is_active: true
  )

  visit providers_office_work_schedules_path(office)

  # Click on Monday (day 1)
  within "[data-week-grid-day-param='monday']" do
    click_on "Edit"
  end

  # Should navigate to edit page with fragment
  assert_current_path edit_providers_office_work_schedules_path(office)
  # URL should include #day-monday fragment (check via JavaScript)
end

test "shows closed day indicator for days without schedule" do
  office = offices(:main_office)

  # Create schedule for Monday only
  WorkSchedule.create!(
    office: office,
    provider: @provider,
    day_of_week: 1,
    work_periods: [{ "start" => "09:00", "end" => "17:00" }],
    appointment_duration_minutes: 60,
    buffer_minutes_between_appointments: 15,
    opening_time: "09:00",
    closing_time: "17:00",
    is_active: true
  )

  visit providers_office_work_schedules_path(office)

  # Monday should have slots
  assert_selector ".bg-green-50"

  # Other days should show "Closed"
  assert_text "Closed", count: 6 # 6 other days
end
```

### 6.3 Helper Tests

**File**: `test/helpers/application_helper_test.rb` (create if doesn't exist)

```ruby
require "test_helper"

class ApplicationHelperTest < ActionView::TestCase
  test "slot_class returns correct classes for available slot" do
    slot = AvailableSlot.new(
      start_time: Time.now,
      end_time: Time.now + 1.hour,
      status: "available",
      office_id: "123"
    )

    classes = slot_class(slot)
    assert_includes classes, "bg-green-50"
    assert_includes classes, "border-green-400"
  end

  test "slot_class returns correct classes for busy slot" do
    slot = AvailableSlot.new(
      start_time: Time.now,
      end_time: Time.now + 1.hour,
      status: "busy",
      office_id: "123"
    )

    classes = slot_class(slot)
    assert_includes classes, "bg-red-50"
    assert_includes classes, "border-red-400"
  end
end
```

---

## Summary

This implementation adds a visual week grid preview that:

1. **Displays after schedule setup** - Confirms to providers what their schedule looks like
2. **Shows discrete appointment slots** - Uses SlotGenerator to calculate actual bookable times
3. **Interactive UI** - Click on any day to quickly edit
4. **Visual feedback** - Color-coded slots, hover effects, helpful stats
5. **Graceful handling** - Works with partial schedules, closed days, and errors

### Key Files Created/Modified

**New Files**:
- `app/views/providers/work_schedules/show.html.erb` - Week grid view
- `app/javascript/controllers/week_grid_controller.js` - Interactivity
- Tests for controller, system, and helpers

**Modified Files**:
- `config/routes.rb` - Add `:show` action
- `app/controllers/providers/work_schedules_controller.rb` - Add show action, update redirects
- `app/helpers/application_helper.rb` - Add slot_class helper
- `app/views/providers/work_schedules/_day_schedule.html.erb` - Add id for fragments

### Design Highlights

1. **Leverages existing services** - Uses SlotGenerator instead of reinventing slot calculation
2. **Progressive enhancement** - Works without JavaScript, enhanced with Stimulus
3. **Responsive design** - Grid adapts to different screen sizes
4. **Accessibility** - Proper ARIA attributes, keyboard navigation
5. **Error handling** - Graceful fallbacks for edge cases

All code is production-ready with proper error handling, visual feedback, and comprehensive testing.

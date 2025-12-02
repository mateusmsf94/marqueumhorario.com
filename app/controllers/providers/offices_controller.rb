class Providers::OfficesController < ApplicationController
  before_action :authenticate_user!
  before_action :set_office, only: [ :edit, :update, :destroy ]

  def index
    @offices = current_user.offices
  end

  def new
    @office = Office.new
  end

  def create
    @office = Office.new(office_params)

    if @office.save
      # Add current user as office manager
      @office.add_manager(current_user)

      redirect_to new_providers_office_work_schedules_path(@office),
        notice: "Office created! Now let's set up your weekly schedule."    else
      render :new, status: :unprocessable_entity
    end
  end

  def edit
  end

  def update
    if @office.update(office_params)
      redirect_to providers_dashboard_path, notice: "Office updated successfully!"
    else
      render :edit, status: :unprocessable_entity
    end
  end

  def destroy
    if @office.destroy
      redirect_to providers_dashboard_path, notice: "Office deleted successfully."
    else
      redirect_to providers_dashboard_path,
        alert: "Cannot delete office: #{@office.errors.full_messages.join(', ')}"
    end
  end

  private

  def set_office
    @office = current_user.offices.find(params[:id])
  end

  def office_params
    params.require(:office).permit(:name, :address, :city, :state, :zip_code, :time_zone)
  end
end

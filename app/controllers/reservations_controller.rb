class ReservationsController < ApplicationController
  def index
    reservations = Reservation.all
    render json: reservations
  end

  def show
    reservation = Reservation.find(params[:id])
    render json: reservation
  end

  def create
    reservation = Reservation.new(reservation_params)

    if reservation.save
      render json: reservation, status: :created
    else
      render json: { errors: reservation.errors.full_messages }, status: :unprocessable_entity
    end
  end

  def update
    reservation = Reservation.find(params[:id])

    if reservation.update(reservation_params)
      render json: reservation
    else
      render json: { errors: reservation.errors.full_messages }, status: :unprocessable_entity
    end
  end

  def destroy
    reservation = Reservation.find(params[:id])
    reservation.destroy
    head :no_content
  end

  private

  def reservation_params
    params.permit(:room_id, :user_id, :group_id, :link_id, :start_time, :end_time, :purpose, :priority)
  end
end

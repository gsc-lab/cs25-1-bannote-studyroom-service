class RoomsController < ApplicationController
  # ?꾩껜 議고쉶
  def index
    render json: Room.all
  end

  # ?④굔 議고쉶
  def show
    room = Room.find(params[:id])
    render json: room
  rescue ActiveRecord::RecordNotFound
    render json: { error: 'Room not found' }, status: :not_found
  end

  # ?앹꽦
  def create
    room = Room.new(room_params)
    if room.save
      render json: room, status: :created
    else
      render json: room.errors, status: :unprocessable_entity
    end
  end

  # ?섏젙
  def update
    room = Room.find(params[:id])
    if room.update(room_params)
      render json: room
    else
      render json: room.errors, status: :unprocessable_entity
    end
  end

  # ??젣
  def destroy
    room = Room.find(params[:id])
    room.destroy
    render json: { message: 'Room deleted successfully' }
  end

  private

  def room_params
    params.permit(:name, :maximum_member)
  end
end

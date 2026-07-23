class RoomsController < ApplicationController
  # 전체 조회
  def index
    render json: Room.all
  end

  # 단건 조회
  def show
    room = Room.find(params[:id])
    render json: room
  rescue ActiveRecord::RecordNotFound
    render json: { error: 'Room not found' }, status: :not_found
  end

  # 생성
  def create
    room = Room.new(room_params)
    if room.save
      render json: room, status: :created
    else
      render json: room.errors, status: :unprocessable_entity
    end
  end

  # 수정
  def update
    room = Room.find(params[:id])
    if room.update(room_params)
      render json: room
    else
      render json: room.errors, status: :unprocessable_entity
    end
  end

  # 삭제
  def destroy
    room = Room.find(params[:id])
    room.destroy
    render json: { message: 'Room deleted successfully' }
  end

  private

  # 참고: rooms 테이블/gRPC RoomService 에는 capacity, department_code,
  # department_name, status 도 있는데 여기서는 name/maximum_member만 받는다.
  # 이 REST 컨트롤러가 gRPC 쪽과 별개로 어디까지 필드를 열어줄지 정해진 게
  # 없어서 우선 기존 동작 그대로 두고 코멘트만 남김.
  def room_params
    params.permit(:name, :maximum_member)
  end
end

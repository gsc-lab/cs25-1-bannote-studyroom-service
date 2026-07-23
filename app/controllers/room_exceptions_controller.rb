# 참고: 아직 액션이 구현되지 않았지만 routes.rb 는 이 컨트롤러에
# resources :room_exceptions 전체 REST 라우트를 열어두고 있어서,
# 지금 이 경로로 요청이 오면 AbstractController::ActionNotFound 로 500이 난다.
#
# room_exceptions 의 실제 도메인 로직(날짜 범위 조회, 중복/시간 포맷 검증,
# 충돌하는 예약 자동 취소 등)은 grpc_service/service/room_exception_service.rb 에
# 이미 구현되어 있고, 그쪽은 "기간을 지정해 예외 목록을 한 번에 갈아끼우는" 배치
# API라 여기 REST 스타일 개별 CRUD로 그대로 옮기기엔 의미가 달라서 보류함.
# REST로도 노출할지, 이 컨트롤러/라우트 자체를 정리할지는 팀 결정이 필요해 보임.
class RoomExceptionsController < ApplicationController
end

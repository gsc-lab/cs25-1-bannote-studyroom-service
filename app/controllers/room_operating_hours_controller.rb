# 참고: 아직 액션이 구현되지 않았지만 routes.rb 는 이 컨트롤러에
# resources :room_operating_hours 전체 REST 라우트를 열어두고 있어서,
# 지금 이 경로로 요청이 오면 AbstractController::ActionNotFound 로 500이 난다.
#
# room_operating_hours 의 실제 도메인 로직(요일 중복 방지, 시간 포맷 검증 등)은
# grpc_service/service/room_operating_hour_service.rb 에 이미 구현되어 있는데,
# 그쪽은 "방 하나의 요일별 운영시간 전체를 한 번에 갈아끼우는" 배치 API라
# 여기 REST 스타일의 개별 CRUD(index/show/create/update/destroy)로 그대로
# 옮기기엔 의미가 달라서 보류함. REST로도 노출할지, 아니면 이 컨트롤러/라우트
# 자체를 정리할지는 팀 결정이 필요해 보임.
class RoomOperatingHoursController < ApplicationController
end

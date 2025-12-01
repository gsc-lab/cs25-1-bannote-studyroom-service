# frozen_string_literal: true

require 'room_exception/room_exception_pb'
require 'room_exception/service_pb'
require 'room_exception/service_services_pb'

require_relative '../../app/models/concerns/current'

module Bannote
  module Studyroomservice
    module Roomexception
      module V1
        class RoomExceptionServiceHandler < RoomExceptionService::Service

          ROLE_PRIORITY = {
            "student"   => 1,
            "assistant" => 2,
            "professor" => 3,
            "admin"     => 4
          }.freeze

          # =========================================
          # 1) ?꾩껜 議고쉶
          # =========================================
          def get_room_exceptions(request, _call)
            authorize!("student")

            scope = ::RoomException.where(room_id: request.room_id, deleted_at: nil)

            # from_date, to_date ?????덉쓣 寃쎌슦
            if request.from_date.present? && request.to_date.present?
              start_date = Date.parse(request.from_date)
              end_date = Date.parse(request.to_date)
              scope = scope.where(holiday_date: start_date..end_date)

            # from_date 留??덈뒗 寃쎌슦
            elsif request.from_date.present?
              start_date = Date.parse(request.from_date)
              scope = scope.where("holiday_date >= ?", start_date)

            # to_date 留??덈뒗 寃쎌슦
            elsif request.to_date.present?
              end_date = Date.parse(request.to_date)
              scope = scope.where("holiday_date <= ?", end_date)
            end

            exceptions = scope.order(:holiday_date)

            response_items = exceptions.map { |ex| room_exception_to_proto(ex) }

            GetRoomExceptionsResponse.new(
              room_exceptions: response_items
            )
          end

          # =========================================
          # 2) 踰붿쐞 湲곕컲 ?낅뜲?댄듃
          # =========================================
          def update_room_exceptions(request, _call)
            authorize!("assistant")

            room_id = request.room_id
            from_date = Date.parse(request.from_date)
            to_date = request.to_date.present? ? Date.parse(request.to_date) : nil

            incoming_items = request.exceptions.to_a
            incoming_dates = incoming_items.map(&:holiday_date).map(&:to_s)

            # 踰붿쐞???대떦?섎뒗 湲곗〈 ?곗씠???쎄린
            scope = ::RoomException.where(room_id: room_id, deleted_at: nil)

            scope =
              if to_date
                scope.where(holiday_date: from_date..to_date)
              else
                scope.where("holiday_date >= ?", from_date)
              end

            existing = scope.index_by { |ex| ex.holiday_date.to_s }

            # ?좉퇋 + ?섏젙 泥섎━
            ActiveRecord::Base.transaction do
              incoming_items.each do |item|
                date_str = item.holiday_date.to_s

                # ?좎쭨 寃利?
                validate_holiday_date!(date_str)

                opening = item.opening_time.presence
                closing = item.closing_time.presence

                validate_exception_time_format!(opening, closing)

                if existing[date_str]
                  existing[date_str].update!(
                    reason: item.reason,
                    opening_time: opening,
                    closing_time: closing
                  )
                else
                  target_date = Date.parse(date_str)
                  if to_date.nil? || (from_date..to_date).cover?(target_date)
                    ::RoomException.create!(
                      room_id: room_id,
                      holiday_date: date_str,
                      reason: item.reason,
                      opening_time: opening,
                      closing_time: closing,
                      created_by: Current.user_code
                    )
                  end
                end
              end

  
              # ??젣 泥섎━
  
              existing.each do |date_str, record|
                next if incoming_dates.include?(date_str)
                record.update!(deleted_at: Time.current)
              end
            end

            UpdateRoomExceptionsResponse.new(
              from_date: request.from_date,
              to_date: request.to_date
            )
          end

          # =========================================
          # ?좏떥 / 寃利?
          # =========================================
          private

          def hhmm_to_minutes(hhmm)
            return nil if hhmm.nil?
            h, m = hhmm.split(":").map(&:to_i)
            (h * 60) + m
          end

          def validate_holiday_date!(date)
            raise_invalid("holiday_date is required") unless date.present?
            Date.parse(date)
          rescue
            raise_invalid("Invalid date format for holiday_date. Expected YYYY-MM-DD.")
          end

          def validate_exception_time_format!(opening, closing)
            opening = opening.presence
            closing = closing.presence

            return if opening.nil? && closing.nil?

            if opening.nil? && closing.present?
              raise_invalid("opening_time is required when closing_time is provided")
            end
            if closing.nil? && opening.present?
              raise_invalid("closing_time is required when opening_time is provided")
            end

            begin
              start_m = hhmm_to_minutes(opening)
              end_m = hhmm_to_minutes(closing)
            rescue
              raise_invalid("Invalid time format. Expected HH:MM.")
            end

            if start_m.nil? || end_m.nil?
              raise_invalid("Invalid time format. Expected HH:MM.")
            end

            raise_invalid("opening_time must be before closing_time") if start_m >= end_m
          end

          # proto 蹂??
          def room_exception_to_proto(exception)
            RoomException.new(
              id: exception.id,
              room_id: exception.room_id,
              holiday_date: exception.holiday_date.to_s,
              reason: exception.reason,
              opening_time: exception.opening_time,
              closing_time: exception.closing_time,
              created_by: exception.created_by,
              created_at: Google::Protobuf::Timestamp.new(seconds: exception.created_at.to_i),
              updated_at: Google::Protobuf::Timestamp.new(seconds: exception.updated_at.to_i)
            )
          end

          # ?먮윭
          def raise_invalid(msg); raise GRPC::BadStatus.new(GRPC::Core::StatusCodes::INVALID_ARGUMENT, msg); end
          def raise_not_found(msg); raise GRPC::BadStatus.new(GRPC::Core::StatusCodes::NOT_FOUND, msg); end
          def raise_precondition(msg); raise GRPC::BadStatus.new(GRPC::Core::StatusCodes::FAILED_PRECONDITION, msg); end

          # 沅뚰븳 寃??
          def authorize!(required_role)
            user_role = Current.user_role.to_s
            unless ROLE_PRIORITY[user_role] && ROLE_PRIORITY[user_role] >= ROLE_PRIORITY[required_role]
              raise GRPC::BadStatus.new(GRPC::Core::StatusCodes::PERMISSION_DENIED, "Permission denied")
            end
          end
        end
      end
    end
  end
end

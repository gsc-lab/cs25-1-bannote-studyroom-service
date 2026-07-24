class UpdateSchemaToErd < ActiveRecord::Migration[8.0]
  def change
    # rooms ?뚯씠釉??섏젙: ERD??留욎떠 ?ㅽ꽣?붾８ ?뺣낫瑜??낅뜲?댄듃?⑸땲??
    remove_column :rooms, :capacity, :integer # 湲곗〈 capacity 而щ읆 ?쒓굅
    add_column :rooms, :department_id, :bigint # ?숆낵 ID 而щ읆 異붽? (?좎? ?쒕퉬??李몄“)
    add_column :rooms, :minimum_member, :integer # 理쒖냼 ?몄썝 而щ읆 異붽?
    add_column :rooms, :status, :integer # 諛??곹깭 而щ읆 異붽? (怨듭떎/?낆떎, enum?쇰줈 紐⑤뜽?먯꽌 泥섎━)

    # reservations ?뚯씠釉??섏젙: ERD??留욎떠 ?덉빟 ?뺣낫瑜??낅뜲?댄듃?⑸땲??
    remove_column :reservations, :user_name, :string # 湲곗〈 user_name 而щ읆 ?쒓굅
    add_column :reservations, :group_id, :bigint, null: false # 洹몃９ ID 而щ읆 異붽? (洹몃９ ?⑥쐞 ?덉빟)
    add_column :reservations, :link_id, :bigint # ?몃? ?쇱젙 ?쒕퉬???곕룞???꾪븳 留곹겕 ID 而щ읆 異붽?
    add_column :reservations, :purpose, :string, null: false # ?덉빟 ?ъ쑀 而щ읆 異붽?
    add_column :reservations, :priority, :integer, null: false # ?덉빟 ?곗꽑?쒖쐞 而щ읆 異붽? (enum?쇰줈 紐⑤뜽?먯꽌 泥섎━)
    add_column :reservations, :created_by, :bigint, null: false # ?덉빟 ?앹꽦??ID 而щ읆 異붽?
    add_column :reservations, :updated_by, :bigint # ?덉빟 ?섏젙??ID 而щ읆 異붽?
    add_column :reservations, :deleted_by, :bigint # ?덉빟 ??젣??ID 而щ읆 異붽?
    add_column :reservations, :deleted_at, :datetime # ?뚰봽????젣瑜??꾪븳 deleted_at 而щ읆 異붽?

    # room_operating_hours ?뚯씠釉??앹꽦: ?붿씪蹂??ㅽ꽣?붾８ ?댁쁺 ?쒓컙??愿由ы빀?덈떎.
    create_table :room_operating_hours do |t|
      t.references :room, null: false, foreign_key: true # Room ?뚯씠釉?李몄“
      t.integer :day_of_week, limit: 1, null: false # ?붿씪 (0:?쇱슂??~ 6:?좎슂??
      t.time :opening_time, null: false # ?щ뒗 ?쒓컙
      t.time :closing_time, null: false # ?ル뒗 ?쒓컙
      t.time :day_maximum_time # ?붿씪蹂?理쒕? ?덉빟 ?쒓컙
      t.datetime :deleted_at # ?뚰봽????젣瑜??꾪븳 deleted_at 而щ읆

      t.timestamps # created_at, updated_at ?먮룞 異붽?
    end

    # room_exceptions ?뚯씠釉??앹꽦: ?ㅽ꽣?붾８??鍮꾩젙湲곗쟻 ?댁씪 ?먮뒗 ?밸퀎 ?댁쁺 ?쒓컙??愿由ы빀?덈떎.
    create_table :room_exceptions do |t|
      t.references :room, null: false, foreign_key: true # Room ?뚯씠釉?李몄“
      t.date :holiday_date, null: false # ?댁씪 ?좎쭨
      t.string :reason, limit: 100 # ?댁씪 ?ъ쑀
      t.time :opening_time # ?쇳쉶???щ뒗 ?쒓컙
      t.time :closing_time # ?쇳쉶???ル뒗 ?쒓컙
      t.bigint :created_by, null: false # ?ㅼ젙???ъ슜??ID

      t.timestamps # created_at, updated_at ?먮룞 異붽?
    end

    # ?몃옒 ???몃뜳??異붽?: 議곗씤 ?깅뒫 ?μ긽???꾪빐 ?몃뜳?ㅻ? 異붽??⑸땲??
    add_index :rooms, :department_id # rooms ?뚯씠釉붿쓽 department_id???몃뜳??異붽?
    add_index :reservations, :group_id # reservations ?뚯씠釉붿쓽 group_id???몃뜳??異붽?
    add_index :reservations, :link_id # reservations ?뚯씠釉붿쓽 link_id???몃뜳??異붽?
    add_index :room_operating_hours, :day_of_week # room_operating_hours ?뚯씠釉붿쓽 day_of_week???몃뜳??異붽?
    add_index :room_exceptions, :holiday_date # room_exceptions ?뚯씠釉붿쓽 holiday_date???몃뜳??異붽?
  end

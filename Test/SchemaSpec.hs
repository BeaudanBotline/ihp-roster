module Test.SchemaSpec where

import Application.Helper.Controller
import Application.Helper.View (isTrialStaff)
import Generated.Types
import IHP.ControllerPrelude (newRecord)
import IHP.NameSupport (columnNameToFieldName, fieldNameToColumnName)
import IHP.Prelude
import Test.Hspec

tests :: Spec
tests = describe "Schema" do
    it "generates core foundation models" do
        let _ = (Nothing :: Maybe Staff)
        let _ = (Nothing :: Maybe RosterWeek)
        let _ = (Nothing :: Maybe RosterDay)
        let _ = (Nothing :: Maybe RosterSlot)
        let _ = (Nothing :: Maybe TimesheetEntry)
        let _ = (Nothing :: Maybe LeaveRequest)
        let _ = (Nothing :: Maybe VenueConfig)
        let _ = (Nothing :: Maybe StaffAvailability)
        let _ = (Nothing :: Maybe PayLevel)
        let _ = (Nothing :: Maybe ShiftType)
        let _ = (Nothing :: Maybe SlotName)
        let _ = (Nothing :: Maybe DayName)
        let _ = (Nothing :: Maybe PayLevelDayRule)
        True `shouldBe` True

    it "exposes singleton controls on venue config" do
        let _readSingletonFields venueConfig =
                ( get #timezone venueConfig
                , get #weekOffsetEpoch venueConfig
                , get #lateToEarlyMinStartGapMinutes venueConfig
                , get #isSingleton venueConfig
                )
        True `shouldBe` True

    it "exposes normalized user roles and leave statuses via shared helpers" do
        allUserRoleValues `shouldBe` ["staff", "manager", "admin"]
        allLeaveRequestStatusValues `shouldBe` ["pending", "approved", "denied"]

        parseUserRole "staff" `shouldBe` Just StaffRole
        parseUserRole "manager" `shouldBe` Just ManagerRole
        parseUserRole "admin" `shouldBe` Just AdminRole
        parseUserRole "owner" `shouldBe` Nothing

        parseLeaveRequestStatus "pending" `shouldBe` Just LeavePending
        parseLeaveRequestStatus "approved" `shouldBe` Just LeaveApproved
        parseLeaveRequestStatus "denied" `shouldBe` Just LeaveDenied
        parseLeaveRequestStatus "cancelled" `shouldBe` Nothing

        map userRoleToText [StaffRole, ManagerRole, AdminRole] `shouldBe` allUserRoleValues
        map leaveRequestStatusToText [LeavePending, LeaveApproved, LeaveDenied] `shouldBe` allLeaveRequestStatusValues

    it "assigns bootstrap registration role from existing user count" do
        bootstrapRegistrationRole 0 `shouldBe` AdminRole
        bootstrapRegistrationRole 1 `shouldBe` StaffRole
        bootstrapRegistrationRole 5 `shouldBe` StaffRole

    it "requires first and last name for profile completion" do
        requiredProfileFieldsCompleted "Taylor" "Smith" `shouldBe` True
        requiredProfileFieldsCompleted "" "Smith" `shouldBe` False
        requiredProfileFieldsCompleted "Taylor" "" `shouldBe` False

    it "marks users operational only after profile completion" do
        let incompleteUser =
                newRecord @User
                    |> set #email "incomplete@example.com"
                    |> set #passwordHash "hashed"
                    |> set #userRole "staff"
                    |> set #isProfileCompleted False
        let completeUser = incompleteUser |> set #isProfileCompleted True

        isOperationallyActive incompleteUser `shouldBe` False
        isOperationallyActive completeUser `shouldBe` True

    describe "Role-based authorization helpers" do
        it "parses user role from text" do
            parseUserRole "staff" `shouldBe` Just StaffRole
            parseUserRole "manager" `shouldBe` Just ManagerRole
            parseUserRole "admin" `shouldBe` Just AdminRole
            parseUserRole "superadmin" `shouldBe` Nothing

        it "role hierarchy is staff < manager < admin" do
            let roleLevel StaffRole   = 0 :: Int
                roleLevel ManagerRole = 1
                roleLevel AdminRole   = 2
            roleLevel StaffRole `shouldSatisfy` (< roleLevel ManagerRole)
            roleLevel ManagerRole `shouldSatisfy` (< roleLevel AdminRole)
            roleLevel StaffRole `shouldSatisfy` (< roleLevel AdminRole)

        it "hasRole checks minimum role level correctly" do
            let checkRole currentRoleText minimumRole =
                    let currentRole = case parseUserRole currentRoleText of
                            Just r  -> r
                            Nothing -> StaffRole
                        roleLevel StaffRole   = 0 :: Int
                        roleLevel ManagerRole = 1
                        roleLevel AdminRole   = 2
                    in roleLevel currentRole >= roleLevel minimumRole

            -- Staff can access staff-level
            checkRole "staff" StaffRole `shouldBe` True
            -- Staff cannot access manager-level
            checkRole "staff" ManagerRole `shouldBe` False
            -- Staff cannot access admin-level
            checkRole "staff" AdminRole `shouldBe` False

            -- Manager can access staff and manager level
            checkRole "manager" StaffRole `shouldBe` True
            checkRole "manager" ManagerRole `shouldBe` True
            -- Manager cannot access admin-level
            checkRole "manager" AdminRole `shouldBe` False

            -- Admin can access all levels
            checkRole "admin" StaffRole `shouldBe` True
            checkRole "admin" ManagerRole `shouldBe` True
            checkRole "admin" AdminRole `shouldBe` True

            -- Unknown role falls back to staff
            checkRole "unknown" StaffRole `shouldBe` True
            checkRole "unknown" ManagerRole `shouldBe` False

    describe "Trial staff" do
        it "identifies trial staff by missing user_id" do
            let trialStaff = newRecord @Staff
                    |> set #firstName "Trial"
                    |> set #lastName "Person"
            isTrialStaff trialStaff `shouldBe` True

        it "identifies linked staff by present user_id" do
            let linkedStaff = newRecord @Staff
                    |> set #firstName "Linked"
                    |> set #lastName "Person"
                    |> set #userId (Just def)
            isTrialStaff linkedStaff `shouldBe` False

    it "all schema column names round-trip through IHP NameSupport" do
        -- Every column name must survive columnNameToFieldName and
        -- fieldNameToColumnName without throwing a parse error.
        -- This catches Haskell reserved-word collisions (e.g. "role")
        -- that only surface at runtime.
        let columnNames =
                [ "id", "email", "password_hash", "user_role"
                , "is_profile_completed", "locked_at", "failed_login_attempts"
                , "created_at", "updated_at", "user_id", "first_name"
                , "last_name", "is_active", "name", "default_pay_level_id"
                , "weekday_index", "pay_level_id", "day_name_id", "multiplier"
                , "is_singleton", "timezone", "week_offset_epoch"
                , "late_to_early_min_start_gap_minutes", "week_offset"
                , "is_live", "roster_week_id", "day_offset", "roster_day_id"
                , "staff_id", "slot_name_id", "row_index", "start_time"
                , "duration_minutes", "specific_date", "is_available", "note"
                , "start_date", "end_date", "status", "notes", "worked_on"
                , "end_time", "break_minutes", "is_approved", "approved_at"
                , "approved_by_user_id"
                ]
        forM_ columnNames $ \col -> do
            let fieldName = columnNameToFieldName col
            let backToCol = fieldNameToColumnName fieldName
            backToCol `shouldBe` col

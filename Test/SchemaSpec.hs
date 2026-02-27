module Test.SchemaSpec where

import Application.Helper.Controller
import Generated.Types
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

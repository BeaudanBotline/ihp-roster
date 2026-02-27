module Test.SchemaSpec where

import IHP.Prelude
import Generated.Types
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

module Test.ConflictSpec where

import Application.Helper.Conflict
import Data.Time.Calendar (fromGregorian)
import Generated.Types
import IHP.Prelude
import Test.Hspec

tests :: Spec
tests = describe "Conflict Engine" do
    let mockDate = fromGregorian 2025 1 6 -- A Monday

    let mockSlot = RosterSlot
            { id = def
            , rosterDayId = def
            , staffId = Nothing
            , slotNameId = def
            , shiftTypeId = def
            , startTime = def
            , durationMinutes = Nothing
            , createdAt = def
            , updatedAt = def
            , meta = def
            }

    let mockLeaveRequest = LeaveRequest
            { id = def
            , staffId = def
            , startDate = fromGregorian 2025 1 5
            , endDate = fromGregorian 2025 1 7
            , status = "approved"
            , notes = Nothing
            , createdAt = def
            , updatedAt = def
            , meta = def
            }

    let mockAvailability = StaffAvailability
            { id = def
            , staffId = def
            , weekdayIndex = Just 1 -- Monday
            , specificDate = Nothing
            , isAvailable = False
            , note = Nothing
            , createdAt = def
            , updatedAt = def
            , meta = def
            }

    it "detects duplicate assignments on the same day" do
        let ctx = ConflictContext
                { slot = mockSlot
                , weekSlots = [mockSlot, mockSlot]
                , daySlots = [mockSlot, mockSlot]
                , leaveRequests = []
                , availabilities = []
                , rosterDayDate = mockDate
                , staffIdealShifts = Nothing
                }
        let conflicts = evaluateConflicts ctx
        length conflicts `shouldBe` 1
        map conflictType conflicts `shouldBe` [DuplicateAssignment]

    it "detects leave conflicts for approved leave on the given day" do
        let ctx = ConflictContext
                { slot = mockSlot
                , weekSlots = [mockSlot]
                , daySlots = [mockSlot]
                , leaveRequests = [mockLeaveRequest]
                , availabilities = []
                , rosterDayDate = mockDate
                , staffIdealShifts = Nothing
                }
        let conflicts = evaluateConflicts ctx
        length conflicts `shouldBe` 1
        map conflictType conflicts `shouldBe` [LeaveConflict]

    it "detects availability refusals for matching day" do
        let ctx = ConflictContext
                { slot = mockSlot
                , weekSlots = [mockSlot]
                , daySlots = [mockSlot]
                , leaveRequests = []
                , availabilities = [mockAvailability]
                , rosterDayDate = mockDate
                , staffIdealShifts = Nothing
                }
        let conflicts = evaluateConflicts ctx
        length conflicts `shouldBe` 1
        map conflictType conflicts `shouldBe` [AvailabilityRefusal]

    it "detects ideal-shift threshold exceeded" do
        let ctx = ConflictContext
                { slot = mockSlot
                , weekSlots = [mockSlot, mockSlot, mockSlot]
                , daySlots = [mockSlot]
                , leaveRequests = []
                , availabilities = []
                , rosterDayDate = mockDate
                , staffIdealShifts = Just 2
                }
        let conflicts = evaluateConflicts ctx
        length conflicts `shouldBe` 1
        map conflictType conflicts `shouldBe` [IdealShiftThresholdExceeded]

    it "sorts multiple conflicts by severity/priority" do
        let ctx = ConflictContext
                { slot = mockSlot
                , weekSlots = [mockSlot, mockSlot, mockSlot]
                , daySlots = [mockSlot, mockSlot] -- duplicate
                , leaveRequests = []
                , availabilities = []
                , rosterDayDate = mockDate
                , staffIdealShifts = Just 2 -- ideal exceeded
                }
        let conflicts = evaluateConflicts ctx
        length conflicts `shouldBe` 2
        map conflictType conflicts `shouldBe` [DuplicateAssignment, IdealShiftThresholdExceeded]

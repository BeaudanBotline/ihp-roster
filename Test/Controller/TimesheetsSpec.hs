module Test.Controller.TimesheetsSpec where

import Application.Helper.Controller (parseTimeParam)
import Config
import Data.Time.Calendar (fromGregorian)
import Generated.Types
import IHP.ControllerPrelude
import IHP.FrameworkConfig
import IHP.HaskellSupport
import IHP.Prelude
import IHP.Test.Mocking
import Network.HTTP.Types.Status
import Network.Wai
import Test.Hspec
import Test.Support
import Web.Controller.Timesheets ()
import Web.FrontController ()
import Web.Routes
import Web.Types

tests :: Spec
tests = beforeAll testContext do
    describe "TimesheetsController" do
        it "redirects unauthenticated users from timesheets page" $ withContext do
            response <- callAction TimesheetsAction
            response `responseStatusShouldBe` status302

        it "redirects unauthenticated users from weekly timesheets page" $ withContext do
            response <- callAction ShowTimesheetWeekAction { weekOffset = 0 }
            response `responseStatusShouldBe` status302

        it "redirects unauthenticated users from new timesheet entry" $ withContext do
            response <- callAction NewTimesheetEntryAction
            response `responseStatusShouldBe` status302

        it "redirects unauthenticated users from create timesheet entry" $ withContext do
            response <- callAction CreateTimesheetEntryAction
            response `responseStatusShouldBe` status302

        it "redirects unauthenticated users from approve action" $ withContext do
            let entryId = Id "00000000-0000-0000-0000-000000000000"
            response <- callAction ApproveTimesheetEntryAction { timesheetEntryId = entryId }
            response `responseStatusShouldBe` status302

        it "redirects unauthenticated users from unapprove action" $ withContext do
            let entryId = Id "00000000-0000-0000-0000-000000000000"
            response <- callAction UnapproveTimesheetEntryAction { timesheetEntryId = entryId }
            response `responseStatusShouldBe` status302

        it "writes an audit event when approving a timesheet entry" $ withContext do
            withCleanDb do
                venue <- createVenueWithConfig "Timesheet Venue"
                manager <- createUserRecord "timesheet-manager@example.com" "staff" True
                _ <- createVenueMembershipRecord venue manager "manager"
                staff <- createStaffRecord venue Nothing "Tia" "Shift"
                entry <- createTimesheetEntryRecord venue staff (fromGregorian 2025 1 7)

                response <- withUserAndCurrentVenue manager venue.id do
                    callAction ApproveTimesheetEntryAction { timesheetEntryId = entry.id }

                response `responseStatusShouldBe` status302

                updatedEntry <- fetch entry.id
                updatedEntry.isApproved `shouldBe` True
                updatedEntry.approvedByUserId `shouldBe` Just (unpackId manager.id)

                auditEvent <- query @AuditEvent |> fetchOne
                auditEvent.venueId `shouldBe` unpackId venue.id
                auditEvent.actorUserId `shouldBe` unpackId manager.id
                auditEvent.eventType `shouldBe` "timesheet_approved"
                auditEvent.targetTable `shouldBe` "timesheet_entries"
                auditEvent.targetId `shouldBe` unpackId entry.id
                auditEvent.sourceChannel `shouldBe` "web"

        it "writes an audit event when unapproving a timesheet entry" $ withContext do
            withCleanDb do
                venue <- createVenueWithConfig "Timesheet Venue"
                manager <- createUserRecord "timesheet-unapprove@example.com" "staff" True
                _ <- createVenueMembershipRecord venue manager "manager"
                staff <- createStaffRecord venue Nothing "Una" "Shift"
                entry <- createTimesheetEntryRecord venue staff (fromGregorian 2025 1 8)
                    >>= updateRecord
                        . set #isApproved True
                        . set #approvedByUserId (Just (unpackId manager.id))

                response <- withUserAndCurrentVenue manager venue.id do
                    callAction UnapproveTimesheetEntryAction { timesheetEntryId = entry.id }

                response `responseStatusShouldBe` status302

                updatedEntry <- fetch entry.id
                updatedEntry.isApproved `shouldBe` False
                updatedEntry.approvedByUserId `shouldBe` Nothing

                auditEvent <- query @AuditEvent |> fetchOne
                auditEvent.eventType `shouldBe` "timesheet_unapproved"
                auditEvent.targetId `shouldBe` unpackId entry.id

        it "writes an audit event when editing resets a prior approval" $ withContext do
            withCleanDb do
                venue <- createVenueWithConfig "Timesheet Venue"
                manager <- createUserRecord "timesheet-reset@example.com" "staff" True
                _ <- createVenueMembershipRecord venue manager "manager"
                staff <- createStaffRecord venue Nothing "Ria" "Shift"
                entry <- createTimesheetEntryRecord venue staff (fromGregorian 2025 1 9)
                    >>= updateRecord
                        . set #isApproved True
                        . set #approvedByUserId (Just (unpackId manager.id))

                response <- withUserAndCurrentVenue manager venue.id do
                    callActionWithParams (UpdateTimesheetEntryAction entry.id)
                        [ ("staffId", idToParam staff.id)
                        , ("workedOn", "2025-01-09")
                        , ("startTime", "09:15")
                        , ("endTime", "17:15")
                        ]

                response `responseStatusShouldBe` status302

                updatedEntry <- fetch entry.id
                updatedEntry.isApproved `shouldBe` False
                parseTimeParam "09:15" `shouldBe` Just updatedEntry.startTime
                parseTimeParam "17:15" `shouldBe` Just updatedEntry.endTime

                auditEvent <- query @AuditEvent |> fetchOne
                auditEvent.eventType `shouldBe` "timesheet_approval_reset"
                auditEvent.targetId `shouldBe` unpackId entry.id

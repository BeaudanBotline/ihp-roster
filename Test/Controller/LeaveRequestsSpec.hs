module Test.Controller.LeaveRequestsSpec where

import Application.Helper.LiveUpdate (LiveUpdateScope (..),
                                      currentLiveUpdateVersion)
import Config
import Data.Time.Calendar (fromGregorian)
import Data.Time.Clock (UTCTime (..), secondsToDiffTime)
import Generated.Types
import IHP.ControllerPrelude
import IHP.FrameworkConfig
import IHP.HaskellSupport
import IHP.ModelSupport (inputValue)
import IHP.Prelude
import IHP.Test.Mocking
import Network.HTTP.Types.Status
import Test.Hspec
import Test.Support
import Web.Controller.LeaveRequests ()
import Web.FrontController ()
import Web.Routes
import Web.Types

tests :: Spec
tests = beforeAll testContext do
    describe "LeaveRequestsController" do
        it "redirects unauthenticated users from leave requests page" $ withContext do
            response <- callAction LeaveRequestsAction
            response `responseStatusShouldBe` status302

        it "redirects unauthenticated users from new leave request page" $ withContext do
            response <- callAction NewLeaveRequestAction
            response `responseStatusShouldBe` status302

        it "redirects unauthenticated users from create leave request action" $ withContext do
            response <- callAction CreateLeaveRequestAction
            response `responseStatusShouldBe` status302

        it "redirects unauthenticated users from approve leave action" $ withContext do
            let requestId = "00000000-0000-0000-0000-000000000000" :: Id LeaveRequest
            response <- callAction ApproveLeaveRequestAction { leaveRequestId = requestId }
            response `responseStatusShouldBe` status302

        it "redirects unauthenticated users from deny leave action" $ withContext do
            let requestId = "00000000-0000-0000-0000-000000000000" :: Id LeaveRequest
            response <- callAction DenyLeaveRequestAction { leaveRequestId = requestId }
            response `responseStatusShouldBe` status302

        it "redirects unauthenticated users from delete leave action" $ withContext do
            let requestId = "00000000-0000-0000-0000-000000000000" :: Id LeaveRequest
            response <- callAction DeleteLeaveRequestAction { leaveRequestId = requestId }
            response `responseStatusShouldBe` status302

        it "approving leave invalidates affected roster week scopes only in the current venue" $ withContext do
            withCleanDb do
                let staleTimestamp = UTCTime (fromGregorian 2024 12 1) (secondsToDiffTime 0)
                venueA <- createVenueWithConfig "Venue A"
                venueB <- createVenueWithConfig "Venue B"
                manager <- createUserRecord "leave-manager@example.com" "staff" True
                _ <- createVenueMembershipRecord venueA manager "manager"
                staffA <- createStaffRecord venueA Nothing "Ava" "Leave"
                rosterWeekA <- createRosterWeekRecord venueA 0 False >>= updateRecord . set #updatedAt staleTimestamp
                rosterWeekA1 <- createRosterWeekRecord venueA 1 False >>= updateRecord . set #updatedAt staleTimestamp
                rosterWeekB <- createRosterWeekRecord venueB 0 False >>= updateRecord . set #updatedAt staleTimestamp
                leaveRequest <- createLeaveRequestRecord venueA staffA (fromGregorian 2025 1 8) (fromGregorian 2025 1 15) "pending"

                versionA0Before <- currentLiveUpdateVersion RosterWeekScope { venueId = unpackId venueA.id, weekOffset = 0 }
                versionA1Before <- currentLiveUpdateVersion RosterWeekScope { venueId = unpackId venueA.id, weekOffset = 1 }
                versionB0Before <- currentLiveUpdateVersion RosterWeekScope { venueId = unpackId venueB.id, weekOffset = 0 }

                response <- withUserAndCurrentVenue manager venueA.id do
                    callAction ApproveLeaveRequestAction { leaveRequestId = leaveRequest.id }

                response `responseStatusShouldBe` status302

                versionA0After <- currentLiveUpdateVersion RosterWeekScope { venueId = unpackId venueA.id, weekOffset = 0 }
                versionA1After <- currentLiveUpdateVersion RosterWeekScope { venueId = unpackId venueA.id, weekOffset = 1 }
                versionB0After <- currentLiveUpdateVersion RosterWeekScope { venueId = unpackId venueB.id, weekOffset = 0 }
                refreshedWeekA <- fetch rosterWeekA.id
                refreshedWeekA1 <- fetch rosterWeekA1.id
                refreshedWeekB <- fetch rosterWeekB.id

                versionA0After `shouldBe` versionA0Before + 1
                versionA1After `shouldBe` versionA1Before + 1
                versionB0After `shouldBe` versionB0Before
                refreshedWeekA.updatedAt `shouldBe` staleTimestamp
                refreshedWeekA1.updatedAt `shouldBe` staleTimestamp
                refreshedWeekB.updatedAt `shouldBe` staleTimestamp

        it "denying previously approved leave invalidates the affected roster week scope" $ withContext do
            withCleanDb do
                venue <- createVenueWithConfig "Leave Venue"
                manager <- createUserRecord "leave-deny-live-update@example.com" "staff" True
                _ <- createVenueMembershipRecord venue manager "manager"
                staff <- createStaffRecord venue Nothing "Dina" "Leave"
                _ <- createRosterWeekRecord venue 0 False
                leaveRequest <- createLeaveRequestRecord venue staff (fromGregorian 2025 1 8) (fromGregorian 2025 1 10) "approved"

                versionBefore <- currentLiveUpdateVersion RosterWeekScope { venueId = unpackId venue.id, weekOffset = 0 }

                response <- withUserAndCurrentVenue manager venue.id do
                    callAction DenyLeaveRequestAction { leaveRequestId = leaveRequest.id }

                response `responseStatusShouldBe` status302

                versionAfter <- currentLiveUpdateVersion RosterWeekScope { venueId = unpackId venue.id, weekOffset = 0 }
                versionAfter `shouldBe` versionBefore + 1

        it "writes an audit event when approving a leave request" $ withContext do
            withCleanDb do
                venue <- createVenueWithConfig "Leave Venue"
                manager <- createUserRecord "leave-approve@example.com" "staff" True
                _ <- createVenueMembershipRecord venue manager "manager"
                staff <- createStaffRecord venue Nothing "Ava" "Leave"
                leaveRequest <- createLeaveRequestRecord venue staff (fromGregorian 2025 1 8) (fromGregorian 2025 1 10) "pending"

                response <- withUserAndCurrentVenue manager venue.id do
                    callAction ApproveLeaveRequestAction { leaveRequestId = leaveRequest.id }

                response `responseStatusShouldBe` status302

                updatedLeaveRequest <- fetch leaveRequest.id
                inputValue updatedLeaveRequest.status `shouldBe` "approved"

                leaveEvent <- query @LeaveRequestEvent |> fetchOne
                inputValue leaveEvent.eventType `shouldBe` "approved"
                fmap inputValue leaveEvent.previousStatus `shouldBe` Just "pending"
                fmap inputValue leaveEvent.newStatus `shouldBe` Just "approved"

                auditEvent <- query @AuditEvent |> fetchOne
                auditEvent.venueId `shouldBe` unpackId venue.id
                auditEvent.actorUserId `shouldBe` unpackId manager.id
                auditEvent.eventType `shouldBe` "leave_approved"
                auditEvent.targetTable `shouldBe` "leave_requests"
                auditEvent.targetId `shouldBe` unpackId leaveRequest.id

        it "writes an audit event when denying a leave request" $ withContext do
            withCleanDb do
                venue <- createVenueWithConfig "Leave Venue"
                manager <- createUserRecord "leave-deny@example.com" "staff" True
                _ <- createVenueMembershipRecord venue manager "manager"
                staff <- createStaffRecord venue Nothing "Dina" "Leave"
                leaveRequest <- createLeaveRequestRecord venue staff (fromGregorian 2025 1 11) (fromGregorian 2025 1 12) "pending"

                response <- withUserAndCurrentVenue manager venue.id do
                    callAction DenyLeaveRequestAction { leaveRequestId = leaveRequest.id }

                response `responseStatusShouldBe` status302

                updatedLeaveRequest <- fetch leaveRequest.id
                inputValue updatedLeaveRequest.status `shouldBe` "denied"

                leaveEvent <- query @LeaveRequestEvent |> fetchOne
                inputValue leaveEvent.eventType `shouldBe` "denied"
                fmap inputValue leaveEvent.previousStatus `shouldBe` Just "pending"
                fmap inputValue leaveEvent.newStatus `shouldBe` Just "denied"

                auditEvent <- query @AuditEvent |> fetchOne
                auditEvent.eventType `shouldBe` "leave_denied"
                auditEvent.targetId `shouldBe` unpackId leaveRequest.id

        it "writes a leave event when creating a leave request" $ withContext do
            withCleanDb do
                venue <- createVenueWithConfig "Leave Venue"
                user <- createUserRecord "leave-create@example.com" "staff" True
                _ <- createVenueMembershipRecord venue user "worker"
                _ <- createStaffRecord venue (Just user) "Liv" "Create"

                response <- withUserAndCurrentVenue user venue.id do
                    callActionWithParams CreateLeaveRequestAction
                        [ ("startDate", "2025-01-13")
                        , ("endDate", "2025-01-14")
                        , ("notes", "Family event")
                        ]

                response `responseStatusShouldBe` status302

                leaveEvent <- query @LeaveRequestEvent |> fetchOne
                inputValue leaveEvent.eventType `shouldBe` "created"
                leaveEvent.previousStatus `shouldBe` Nothing
                fmap inputValue leaveEvent.newStatus `shouldBe` Just "pending"

        it "writes an audit event when deleting a pending leave request" $ withContext do
            withCleanDb do
                venue <- createVenueWithConfig "Leave Venue"
                manager <- createUserRecord "leave-delete@example.com" "staff" True
                _ <- createVenueMembershipRecord venue manager "manager"
                staff <- createStaffRecord venue Nothing "Del" "Leave"
                leaveRequest <- createLeaveRequestRecord venue staff (fromGregorian 2025 1 13) (fromGregorian 2025 1 14) "pending"

                response <- withUserAndCurrentVenue manager venue.id do
                    callAction DeleteLeaveRequestAction { leaveRequestId = leaveRequest.id }

                response `responseStatusShouldBe` status302

                remainingCount <- query @LeaveRequest |> fetchCount
                remainingCount `shouldBe` 0

                leaveEvent <- query @LeaveRequestEvent |> fetchOne
                inputValue leaveEvent.eventType `shouldBe` "deleted"
                fmap inputValue leaveEvent.previousStatus `shouldBe` Just "pending"
                leaveEvent.newStatus `shouldBe` Nothing

                auditEvent <- query @AuditEvent |> fetchOne
                auditEvent.eventType `shouldBe` "leave_deleted"
                auditEvent.targetId `shouldBe` unpackId leaveRequest.id

        it "blocks deleting a reviewed leave request" $ withContext do
            withCleanDb do
                venue <- createVenueWithConfig "Leave Venue"
                manager <- createUserRecord "leave-reviewed-delete@example.com" "staff" True
                _ <- createVenueMembershipRecord venue manager "manager"
                staff <- createStaffRecord venue Nothing "Rev" "Leave"
                leaveRequest <- createLeaveRequestRecord venue staff (fromGregorian 2025 1 15) (fromGregorian 2025 1 16) "approved"

                response <- withUserAndCurrentVenue manager venue.id do
                    callAction DeleteLeaveRequestAction { leaveRequestId = leaveRequest.id }

                response `responseStatusShouldBe` status302

                remainingCount <- query @LeaveRequest |> fetchCount
                remainingCount `shouldBe` 1

                leaveEventCount <- query @LeaveRequestEvent |> fetchCount
                leaveEventCount `shouldBe` 0

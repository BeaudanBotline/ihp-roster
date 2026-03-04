module Test.Controller.AdminSpec where

import Config
import qualified Data.Aeson as Aeson
import Generated.Types
import IHP.ControllerPrelude
import IHP.FrameworkConfig
import IHP.HaskellSupport
import IHP.Prelude
import IHP.Test.Mocking
import Network.HTTP.Types.Status
import Test.Hspec
import Test.Support
import Web.Controller.Admin ()
import Web.FrontController ()
import Web.Routes
import Web.Types

tests :: Spec
tests = beforeAll testContext do
    describe "AdminController" do
        it "redirects unauthenticated users from admin page" $ withContext do
            response <- callAction AdminAction
            response `responseStatusShouldBe` status302

        it "shows config-table sections and only current-venue config rows" $ withContext do
            withCleanDb do
                venueA <- createVenueWithConfig "Venue A"
                venueB <- createVenueWithConfig "Venue B"
                admin <- createUserRecord "admin-page@example.com" "staff" True
                _ <- createVenueMembershipRecord venueA admin "venue_admin"
                _ <- createVenueMembershipRecord venueB admin "venue_admin"

                payLevelA <- createPayLevelRecord venueA "Level A"
                dayNameA <- createDayNameRecord venueA 1 "Monday"
                _ <- createPayLevelDayRuleRecord payLevelA dayNameA 1.25
                _ <- createShiftTypeRecord venueA payLevelA "Kitchen"
                _ <- createSlotNameRecord venueA "Early"
                _ <- createPayConfigSnapshotRecord venueA admin 1 (Aeson.object [])
                _ <- createPayConfigSnapshotRecord venueA admin 2 (Aeson.object [])

                payLevelB <- createPayLevelRecord venueB "Level B"
                dayNameB <- createDayNameRecord venueB 2 "Tuesday"
                _ <- createPayLevelDayRuleRecord payLevelB dayNameB 1.75
                _ <- createShiftTypeRecord venueB payLevelB "Bar"
                _ <- createSlotNameRecord venueB "Late"

                response <- withUserAndCurrentVenue admin venueA.id do
                    callAction AdminAction

                response `responseStatusShouldBe` status200
                response `responseBodyShouldContain` "Pay Levels"
                response `responseBodyShouldContain` "Pay Level Day Rules"
                response `responseBodyShouldContain` "Shift Types"
                response `responseBodyShouldContain` "Slot Names"
                response `responseBodyShouldContain` "Day Names"
                response `responseBodyShouldContain` "Config Table Overview"
                response `responseBodyShouldContain` "Edits change the current venue draft state only until you save a new pay/config snapshot."
                response `responseBodyShouldContain` "Draft edits on this page do not rewrite historical approvals or exports."
                response `responseBodyShouldContain` "Level A"
                response `responseBodyShouldContain` "Level A on Monday (Monday)"
                response `responseBodyShouldContain` "Kitchen"
                response `responseBodyShouldContain` "Early"
                response `responseBodyShouldContain` "Monday"
                response `responseBodyShouldContain` "Active snapshot: v2"
                response `responseBodyShouldNotContain` "Level B"
                response `responseBodyShouldNotContain` "Level B on Tuesday (Tuesday)"
                response `responseBodyShouldNotContain` "Bar"
                response `responseBodyShouldNotContain` "Late"
                response `responseBodyShouldNotContain` "Tuesday"

        it "rejects non-admin venue members from admin screens" $ withContext do
            withCleanDb do
                venue <- createVenueWithConfig "Venue A"
                manager <- createUserRecord "manager-admin@example.com" "staff" True
                _ <- createVenueMembershipRecord venue manager "manager"

                response <- withUserAndCurrentVenue manager venue.id do
                    callAction AdminAction

                response `responseStatusShouldBe` status403

        it "allows venue owners to access admin config screens" $ withContext do
            withCleanDb do
                venue <- createVenueWithConfig "Venue A"
                owner <- createUserRecord "owner-admin@example.com" "staff" True
                _ <- createVenueMembershipRecord venue owner "venue_owner"

                response <- withUserAndCurrentVenue owner venue.id do
                    callAction AdminAction

                response `responseStatusShouldBe` status200
                response `responseBodyShouldContain` "Config Table Overview"
                response `responseBodyShouldContain` "Pay/Config Snapshots"

        it "creates venue-scoped config table rows from the admin page" $ withContext do
            withCleanDb do
                venue <- createVenueWithConfig "Admin Venue"
                admin <- createUserRecord "admin-create@example.com" "staff" True
                _ <- createVenueMembershipRecord venue admin "venue_admin"
                dayName <- createDayNameRecord venue 1 "Monday"

                payLevelResponse <- withUserAndCurrentVenue admin venue.id do
                    callActionWithParams CreatePayLevelAction
                        [ ("name", "Level 2")
                        , ("isActive", "false")
                        ]
                payLevelResponse `responseStatusShouldBe` status302

                payLevel <- query @PayLevel |> fetchOne
                slotResponse <- withUserAndCurrentVenue admin venue.id do
                    callActionWithParams CreateSlotNameAction
                        [ ("name", "Late")
                        , ("isActive", "true")
                        ]
                slotResponse `responseStatusShouldBe` status302

                dayResponse <- withUserAndCurrentVenue admin venue.id do
                    callActionWithParams CreateDayNameAction
                        [ ("weekdayIndex", "3")
                        , ("name", "Midweek")
                        , ("isActive", "false")
                        ]
                dayResponse `responseStatusShouldBe` status302

                shiftTypeResponse <- withUserAndCurrentVenue admin venue.id do
                    callActionWithParams CreateShiftTypeAction
                        [ ("name", "Supervisor")
                        , ("defaultPayLevelId", idToParam payLevel.id)
                        , ("isActive", "true")
                        ]
                shiftTypeResponse `responseStatusShouldBe` status302

                dayRuleResponse <- withUserAndCurrentVenue admin venue.id do
                    callActionWithParams CreatePayLevelDayRuleAction
                        [ ("payLevelId", idToParam payLevel.id)
                        , ("dayNameId", idToParam dayName.id)
                        , ("multiplier", "1.500")
                        ]
                dayRuleResponse `responseStatusShouldBe` status302

                createdPayLevel <- query @PayLevel |> fetchOne
                createdPayLevelDayRule <- query @PayLevelDayRule |> fetchOne
                createdSlotName <- query @SlotName |> fetchOne
                createdDayName <- query @DayName |> fetchOne
                createdShiftType <- query @ShiftType |> fetchOne

                createdPayLevel.venueId `shouldBe` unpackId venue.id
                createdPayLevel.name `shouldBe` "Level 2"
                createdPayLevel.isActive `shouldBe` False
                createdSlotName.name `shouldBe` "Late"
                createdSlotName.isActive `shouldBe` True
                createdDayName.weekdayIndex `shouldBe` 3
                createdDayName.name `shouldBe` "Midweek"
                createdDayName.isActive `shouldBe` False
                createdPayLevelDayRule.payLevelId `shouldBe` unpackId createdPayLevel.id
                createdPayLevelDayRule.dayNameId `shouldBe` unpackId dayName.id
                createdPayLevelDayRule.multiplier `shouldBe` 1.5
                createdShiftType.name `shouldBe` "Supervisor"
                createdShiftType.defaultPayLevelId `shouldBe` unpackId createdPayLevel.id
                createdShiftType.isActive `shouldBe` True

        it "updates config table rows from the admin page" $ withContext do
            withCleanDb do
                venue <- createVenueWithConfig "Admin Venue"
                admin <- createUserRecord "admin-update@example.com" "staff" True
                _ <- createVenueMembershipRecord venue admin "venue_admin"

                oldPayLevel <- createPayLevelRecord venue "Level 1"
                newPayLevel <- createPayLevelRecord venue "Level 2"
                shiftType <- createShiftTypeRecord venue oldPayLevel "Kitchen"
                slotName <- createSlotNameRecord venue "Early"
                dayName <- createDayNameRecord venue 1 "Monday"
                nextDayName <- createDayNameRecord venue 5 "Friday"
                payLevelDayRule <- createPayLevelDayRuleRecord oldPayLevel dayName 1.25

                payLevelResponse <- withUserAndCurrentVenue admin venue.id do
                    callActionWithParams (UpdatePayLevelAction oldPayLevel.id)
                        [ ("name", "Level 1 Updated")
                        , ("isActive", "false")
                        ]
                payLevelResponse `responseStatusShouldBe` status302

                shiftTypeResponse <- withUserAndCurrentVenue admin venue.id do
                    callActionWithParams (UpdateShiftTypeAction shiftType.id)
                        [ ("name", "Kitchen Updated")
                        , ("defaultPayLevelId", idToParam newPayLevel.id)
                        , ("isActive", "false")
                        ]
                shiftTypeResponse `responseStatusShouldBe` status302

                slotResponse <- withUserAndCurrentVenue admin venue.id do
                    callActionWithParams (UpdateSlotNameAction slotName.id)
                        [ ("name", "Early Updated")
                        , ("isActive", "false")
                        ]
                slotResponse `responseStatusShouldBe` status302

                dayResponse <- withUserAndCurrentVenue admin venue.id do
                    callActionWithParams (UpdateDayNameAction dayName.id)
                        [ ("weekdayIndex", "4")
                        , ("name", "Thursday Updated")
                        , ("isActive", "false")
                        ]
                dayResponse `responseStatusShouldBe` status302

                dayRuleResponse <- withUserAndCurrentVenue admin venue.id do
                    callActionWithParams (UpdatePayLevelDayRuleAction payLevelDayRule.id)
                        [ ("payLevelId", idToParam newPayLevel.id)
                        , ("dayNameId", idToParam nextDayName.id)
                        , ("multiplier", "2.000")
                        ]
                dayRuleResponse `responseStatusShouldBe` status302

                updatedPayLevel <- fetch oldPayLevel.id
                updatedShiftType <- fetch shiftType.id
                updatedSlotName <- fetch slotName.id
                updatedDayName <- fetch dayName.id
                updatedPayLevelDayRule <- fetch payLevelDayRule.id

                updatedPayLevel.name `shouldBe` "Level 1 Updated"
                updatedPayLevel.isActive `shouldBe` False
                updatedShiftType.name `shouldBe` "Kitchen Updated"
                updatedShiftType.defaultPayLevelId `shouldBe` unpackId newPayLevel.id
                updatedShiftType.isActive `shouldBe` False
                updatedSlotName.name `shouldBe` "Early Updated"
                updatedSlotName.isActive `shouldBe` False
                updatedDayName.weekdayIndex `shouldBe` 4
                updatedDayName.name `shouldBe` "Thursday Updated"
                updatedDayName.isActive `shouldBe` False
                updatedPayLevelDayRule.payLevelId `shouldBe` unpackId newPayLevel.id
                updatedPayLevelDayRule.dayNameId `shouldBe` unpackId nextDayName.id
                updatedPayLevelDayRule.multiplier `shouldBe` 2.0

        it "rejects updates to config rows outside the current venue" $ withContext do
            withCleanDb do
                venueA <- createVenueWithConfig "Venue A"
                venueB <- createVenueWithConfig "Venue B"
                admin <- createUserRecord "admin-scope@example.com" "staff" True
                _ <- createVenueMembershipRecord venueA admin "venue_admin"
                _ <- createVenueMembershipRecord venueB admin "venue_admin"
                foreignPayLevel <- createPayLevelRecord venueB "Foreign Level"

                response <- withUserAndCurrentVenue admin venueA.id do
                    callActionWithParams (UpdatePayLevelAction foreignPayLevel.id)
                        [ ("name", "Should Not Work")
                        , ("isActive", "false")
                        ]

                response `responseStatusShouldBe` status403

                unchangedPayLevel <- fetch foreignPayLevel.id
                unchangedPayLevel.name `shouldBe` "Foreign Level"
                unchangedPayLevel.isActive `shouldBe` True

        it "rejects pay level day rules that reference another venue or duplicate an existing weekday rule" $ withContext do
            withCleanDb do
                venueA <- createVenueWithConfig "Venue A"
                venueB <- createVenueWithConfig "Venue B"
                admin <- createUserRecord "admin-day-rule@example.com" "staff" True
                _ <- createVenueMembershipRecord venueA admin "venue_admin"
                _ <- createVenueMembershipRecord venueB admin "venue_admin"

                payLevelA <- createPayLevelRecord venueA "Level A"
                dayNameA <- createDayNameRecord venueA 1 "Monday"
                existingRule <- createPayLevelDayRuleRecord payLevelA dayNameA 1.25

                payLevelB <- createPayLevelRecord venueB "Level B"
                dayNameB <- createDayNameRecord venueB 2 "Tuesday"

                crossVenueResponse <- withUserAndCurrentVenue admin venueA.id do
                    callActionWithParams CreatePayLevelDayRuleAction
                        [ ("payLevelId", idToParam payLevelB.id)
                        , ("dayNameId", idToParam dayNameA.id)
                        , ("multiplier", "1.500")
                        ]
                crossVenueResponse `responseStatusShouldBe` status302

                duplicateResponse <- withUserAndCurrentVenue admin venueA.id do
                    callActionWithParams CreatePayLevelDayRuleAction
                        [ ("payLevelId", idToParam payLevelA.id)
                        , ("dayNameId", idToParam dayNameA.id)
                        , ("multiplier", "1.500")
                        ]
                duplicateResponse `responseStatusShouldBe` status302

                updateForeignRuleResponse <- withUserAndCurrentVenue admin venueA.id do
                    callActionWithParams (UpdatePayLevelDayRuleAction existingRule.id)
                        [ ("payLevelId", idToParam payLevelA.id)
                        , ("dayNameId", idToParam dayNameB.id)
                        , ("multiplier", "2.000")
                        ]
                updateForeignRuleResponse `responseStatusShouldBe` status302

                payLevelDayRules <- query @PayLevelDayRule |> fetch
                length payLevelDayRules `shouldBe` 1

                unchangedRule <- fetch existingRule.id
                unchangedRule.payLevelId `shouldBe` unpackId payLevelA.id
                unchangedRule.dayNameId `shouldBe` unpackId dayNameA.id
                unchangedRule.multiplier `shouldBe` 1.25

        it "creates a new pay/config snapshot version from the admin page" $ withContext do
            withCleanDb do
                venue <- createVenueWithConfig "Admin Venue"
                admin <- createUserRecord "admin-save@example.com" "staff" True
                _ <- createVenueMembershipRecord venue admin "venue_admin"

                response <- withUserAndCurrentVenue admin venue.id do
                    callAction CreatePayConfigSnapshotAction

                response `responseStatusShouldBe` status302

                snapshot <- query @PayConfigSnapshot |> fetchOne
                snapshot.versionNumber `shouldBe` 1
                snapshot.versionLabel `shouldBe` "v1"
                snapshot.createdByUserId `shouldBe` unpackId admin.id

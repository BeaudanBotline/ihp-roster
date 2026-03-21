module Test.Controller.ExportsSpec where

import Application.Helper.Export
import Config
import qualified Data.Aeson as Aeson
import qualified Data.Text as Text
import Data.Time.Calendar (fromGregorian)
import Data.Time.Clock (UTCTime (..), secondsToDiffTime)
import Generated.Types
import IHP.ControllerPrelude
import IHP.FrameworkConfig
import IHP.HaskellSupport
import IHP.Prelude
import IHP.Test.Mocking
import Network.HTTP.Types.Header (hContentDisposition, hContentType)
import Network.HTTP.Types.Status
import Network.Wai (responseHeaders)
import Test.Hspec
import Test.Support
import Web.Controller.Exports ()
import Web.FrontController ()
import Web.Routes
import Web.Types

tests :: Spec
tests = beforeAll testContext do
    describe "ExportsController" do
        it "redirects unauthenticated users from export jobs page" $ withContext do
            response <- callAction ExportJobsAction
            response `responseStatusShouldBe` status302

        it "redirects unauthenticated users from create export job action" $ withContext do
            response <- callAction CreateExportJobAction
            response `responseStatusShouldBe` status302

        it "redirects unauthenticated users from download export job action" $ withContext do
            let exportJobId = Id "00000000-0000-0000-0000-000000000000"
            response <- callAction DownloadExportJobAction { exportJobId }
            response `responseStatusShouldBe` status302

        it "creates an approved-timesheets export job and audits generation" $ withContext do
            withCleanDb do
                let approvedAt = UTCTime (fromGregorian 2025 1 12) (secondsToDiffTime 3600)
                venue <- createVenueWithConfig "Export Venue"
                admin <- createUserRecord "exports-admin@example.com" "staff" True
                _ <- createVenueMembershipRecord venue admin "venue_admin"
                staff <- createStaffRecord venue Nothing "Ava" "Hours"
                snapshot <- createPayConfigSnapshotRecord venue admin 1 (Aeson.object [])
                _ <- createTimesheetEntryRecord venue staff (fromGregorian 2025 1 10)
                    >>= updateRecord
                        . set #payConfigSnapshotId (Just (unpackId snapshot.id))
                        . set #isApproved True
                        . set #approvedAt (Just approvedAt)
                        . set #approvedByUserId (Just (unpackId admin.id))
                _ <- createTimesheetEntryRecord venue staff (fromGregorian 2025 1 11)

                response <- withUserAndCurrentVenue admin venue.id do
                    callActionWithParams CreateExportJobAction
                        [ ("rangeStart", "2025-01-06")
                        , ("rangeEnd", "2025-01-12")
                        ]

                response `responseStatusShouldBe` status302

                exportJob <- query @ExportJob |> fetchOne
                exportJob.venueId `shouldBe` unpackId venue.id
                exportJob.requestedByUserId `shouldBe` unpackId admin.id
                exportJob.exportType `shouldBe` exportJobTypeToText ApprovedTimesheetsCsv
                exportJob.status `shouldBe` exportJobStatusToText ExportReady
                exportJob.rangeStart `shouldBe` Just (fromGregorian 2025 1 6)
                exportJob.rangeEnd `shouldBe` Just (fromGregorian 2025 1 12)
                exportJob.payConfigSnapshotVersion `shouldBe` Just "v1"
                exportJob.fileName `shouldBe` Just "approved-timesheets-2025-01-06-to-2025-01-12.csv"
                exportJob.fileContents `shouldSatisfy` isJust
                fromMaybe "" exportJob.fileContents `shouldSatisfy`
                    Text.isInfixOf "worked_on,staff_name,start_time,end_time,break_minutes,pay_config_snapshot_version,approved_at,approved_by_email"
                fromMaybe "" exportJob.fileContents `shouldSatisfy` Text.isInfixOf "2025-01-10"
                fromMaybe "" exportJob.fileContents `shouldSatisfy` Text.isInfixOf ",v1,"
                fromMaybe "" exportJob.fileContents `shouldSatisfy` (not . Text.isInfixOf "2025-01-11")

                auditEvent <- query @AuditEvent |> fetchOne
                auditEvent.eventType `shouldBe` "export_generated"
                auditEvent.targetTable `shouldBe` "export_jobs"
                auditEvent.targetId `shouldBe` unpackId exportJob.id

        it "downloads a ready export and audits the download" $ withContext do
            withCleanDb do
                venue <- createVenueWithConfig "Export Venue"
                admin <- createUserRecord "exports-download@example.com" "staff" True
                _ <- createVenueMembershipRecord venue admin "venue_admin"
                staff <- createStaffRecord venue Nothing "Bea" "Hours"
                snapshot <- createPayConfigSnapshotRecord venue admin 1 (Aeson.object [])
                _ <- createTimesheetEntryRecord venue staff (fromGregorian 2025 1 10)
                    >>= updateRecord
                        . set #payConfigSnapshotId (Just (unpackId snapshot.id))
                        . set #isApproved True
                        . set #approvedAt (Just (UTCTime (fromGregorian 2025 1 10) (secondsToDiffTime 0)))
                        . set #approvedByUserId (Just (unpackId admin.id))
                _ <- withUserAndCurrentVenue admin venue.id do
                    callActionWithParams CreateExportJobAction
                        [ ("rangeStart", "2025-01-06")
                        , ("rangeEnd", "2025-01-12")
                        ]
                exportJob <- query @ExportJob |> fetchOne

                response <- withUserAndCurrentVenue admin venue.id do
                    callActionWithParams (DownloadExportJobAction exportJob.id)
                        [("token", cs (tshow exportJob.downloadToken))]

                response `responseStatusShouldBe` status200
                lookup hContentType (responseHeaders response) `shouldBe` Just "text/csv; charset=utf-8"
                lookup hContentDisposition (responseHeaders response) `shouldBe` Just "attachment; filename=\"approved-timesheets-2025-01-06-to-2025-01-12.csv\""
                response `responseBodyShouldContain` "Hours, Bea"

                updatedExportJob <- fetch exportJob.id
                updatedExportJob.downloadedByUserId `shouldBe` Just (unpackId admin.id)
                updatedExportJob.downloadedAt `shouldSatisfy` isJust

                auditEvents <- query @AuditEvent |> orderByAsc #createdAt |> fetch
                map (.eventType) auditEvents `shouldBe` ["export_generated", "export_downloaded"]

        it "shows only current-venue export jobs" $ withContext do
            withCleanDb do
                venueA <- createVenueWithConfig "Venue A"
                venueB <- createVenueWithConfig "Venue B"
                admin <- createUserRecord "exports-scope@example.com" "staff" True
                _ <- createVenueMembershipRecord venueA admin "venue_admin"
                _ <- createVenueMembershipRecord venueB admin "venue_admin"
                exportJobA <- newRecord @ExportJob
                    |> set #venueId (unpackId venueA.id)
                    |> set #requestedByUserId (unpackId admin.id)
                    |> set #exportType (exportJobTypeToText ApprovedTimesheetsCsv)
                    |> set #status (exportJobStatusToText ExportReady)
                    |> set #scope (Aeson.object [])
                    |> set #deliveryMethod browserDownloadMethod
                    |> set #destinationMetadata (Aeson.object [])
                    |> set #fileName (Just "venue-a.csv")
                    |> set #contentType (Just "text/csv; charset=utf-8")
                    |> set #fileContents (Just "header")
                    |> set #expiresAt (UTCTime (fromGregorian 2030 2 1) (secondsToDiffTime 0))
                    |> createRecord
                exportJobB <- newRecord @ExportJob
                    |> set #venueId (unpackId venueB.id)
                    |> set #requestedByUserId (unpackId admin.id)
                    |> set #exportType (exportJobTypeToText ApprovedTimesheetsCsv)
                    |> set #status (exportJobStatusToText ExportReady)
                    |> set #scope (Aeson.object [])
                    |> set #deliveryMethod browserDownloadMethod
                    |> set #destinationMetadata (Aeson.object [])
                    |> set #fileName (Just "venue-b.csv")
                    |> set #contentType (Just "text/csv; charset=utf-8")
                    |> set #fileContents (Just "header")
                    |> set #expiresAt (UTCTime (fromGregorian 2030 2 1) (secondsToDiffTime 0))
                    |> createRecord

                response <- withUserAndCurrentVenue admin venueB.id do
                    callAction ExportJobsAction

                response `responseStatusShouldBe` status200
                response `responseBodyShouldContain` "data-disable-javascript-submission=\"true\""
                response `responseBodyShouldContain` tshow exportJobB.id
                response `responseBodyShouldNotContain` tshow exportJobA.id

        it "denies downloading another venue's export job" $ withContext do
            withCleanDb do
                venueA <- createVenueWithConfig "Venue A"
                venueB <- createVenueWithConfig "Venue B"
                admin <- createUserRecord "exports-foreign@example.com" "staff" True
                _ <- createVenueMembershipRecord venueA admin "venue_admin"
                foreignJob <- newRecord @ExportJob
                    |> set #venueId (unpackId venueB.id)
                    |> set #requestedByUserId (unpackId admin.id)
                    |> set #exportType (exportJobTypeToText ApprovedTimesheetsCsv)
                    |> set #status (exportJobStatusToText ExportReady)
                    |> set #scope (Aeson.object [])
                    |> set #deliveryMethod browserDownloadMethod
                    |> set #destinationMetadata (Aeson.object [])
                    |> set #fileName (Just "foreign.csv")
                    |> set #contentType (Just "text/csv; charset=utf-8")
                    |> set #fileContents (Just "header")
                    |> set #expiresAt (UTCTime (fromGregorian 2030 2 1) (secondsToDiffTime 0))
                    |> createRecord

                response <- withUserAndCurrentVenue admin venueA.id do
                    callActionWithParams (DownloadExportJobAction foreignJob.id)
                        [("token", cs (tshow foreignJob.downloadToken))]

                response `responseStatusShouldBe` status403

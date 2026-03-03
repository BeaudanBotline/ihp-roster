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

        it "shows the latest pay/config snapshot version for admins" $ withContext do
            withCleanDb do
                venue <- createVenueWithConfig "Admin Venue"
                admin <- createUserRecord "admin-page@example.com" "staff" True
                _ <- createVenueMembershipRecord venue admin "venue_admin"
                _ <- createPayConfigSnapshotRecord venue admin 1 (Aeson.object [])
                _ <- createPayConfigSnapshotRecord venue admin 2 (Aeson.object [])

                response <- withUserAndCurrentVenue admin venue.id do
                    callAction AdminAction

                response `responseStatusShouldBe` status200
                response `responseBodyShouldContain` "Active snapshot: v2"
                response `responseBodyShouldContain` "Recent Versions"

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

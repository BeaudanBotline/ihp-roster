module Web.Controller.Admin where

import Application.Helper.Pay
import Web.Controller.Prelude
import Web.View.Admin.Index

instance Controller AdminController where
    beforeAction = do
        ensureIsUser
        ensureCurrentVenue
        ensureProfileCompleted
        ensureAdminRole

    action AdminAction = do
        recentSnapshots <- fetchCurrentVenuePayConfigSnapshots
        let latestSnapshot = listToMaybe recentSnapshots
        render IndexView { .. }

    action CreatePayConfigSnapshotAction = do
        snapshot <- createCurrentVenuePayConfigSnapshot
        setSuccessMessage ("Saved pay/config snapshot " <> snapshot.versionLabel)
        redirectTo AdminAction
